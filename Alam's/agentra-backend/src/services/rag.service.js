/**
 * rag.service.js — enhanced keyword & intent-based RAG for Agentra Travel App.
 *
 * Provides robust dataset retrieval for restaurants, food spots, hotels, hostels,
 * hospitals, and tourist attractions across Lahore and Murree with synonym normalization,
 * stemming, intent fallbacks, and city context awareness.
 */
const XLSX = require("xlsx");
const path = require("path");
const fs   = require("fs");

// ── In-memory document store ──────────────────────────────────────────────────
let _docs   = null;   // Array<{ text: string, file: string, city: string, isFaq: boolean, fileCategory: string, tokens: Map<string,number> }>
let _idf    = null;   // Map<string, number>

// ── Helpers ───────────────────────────────────────────────────────────────────

const STOP_WORDS = new Set([
  "the", "a", "an", "in", "on", "of", "to", "is", "are", "was", "were", "be",
  "what", "where", "how", "when", "which", "who", "tell", "me", "about",
  "list", "down", "any", "some", "for", "with", "and", "or", "from", "at", "by", "show", "give",
  "can", "you", "please", "find", "suggest", "good", "best", "top", "nice", "popular"
]);

// Synonym & Stemming Dictionary
const SYNONYM_MAP = {
  // Food & Restaurants
  "restaurant": ["restaurant", "food"],
  "restaurants": ["restaurant", "food"],
  "resturant": ["restaurant", "food"],
  "resturants": ["restaurant", "food"],
  "restorant": ["restaurant", "food"],
  "food": ["restaurant", "food"],
  "foods": ["restaurant", "food"],
  "eat": ["restaurant", "food"],
  "eatery": ["restaurant", "food"],
  "eateries": ["restaurant", "food"],
  "cafe": ["restaurant", "food"],
  "cafes": ["restaurant", "food"],
  "dhaba": ["restaurant", "food"],
  "dhabas": ["restaurant", "food"],
  "dining": ["restaurant", "food"],
  "spot": ["spot", "attraction"],
  "spots": ["spot", "attraction"],

  // Hotels & Accommodation / Hostels
  "hotel": ["hotel", "stay"],
  "hotels": ["hotel", "stay"],
  "hostel": ["hotel", "stay"],
  "hostels": ["hotel", "stay"],
  "guesthouse": ["hotel", "stay"],
  "guesthouses": ["hotel", "stay"],
  "guest": ["hotel", "stay"],
  "stay": ["hotel", "stay"],
  "stays": ["hotel", "stay"],
  "lodging": ["hotel", "stay"],
  "lodge": ["hotel", "stay"],
  "resort": ["hotel", "stay"],
  "resorts": ["hotel", "stay"],
  "inn": ["hotel", "stay"],
  "inns": ["hotel", "stay"],
  "motel": ["hotel", "stay"],

  // Medical / Hospitals
  "hospital": ["hospital", "medical"],
  "hospitals": ["hospital", "medical"],
  "medical": ["hospital", "medical"],
  "clinic": ["hospital", "medical"],
  "clinics": ["hospital", "medical"],
  "doctor": ["hospital", "medical"],
  "doctors": ["hospital", "medical"],
  "emergency": ["hospital", "medical"],

  // Attractions & Places
  "place": ["place", "attraction"],
  "places": ["place", "attraction"],
  "attraction": ["attraction", "place"],
  "attractions": ["attraction", "place"],
  "tourist": ["attraction", "place"],
  "sightseeing": ["attraction", "place"],
  "park": ["park", "attraction"],
  "parks": ["park", "attraction"]
};

function cleanValue(val) {
  if (typeof val !== "string") return val;
  return val
    .replace(/ØŒ/g, ", ")
    .replace(/Ú¯ÙˆØ±Ù.../g, "")
    .replace(/Ã¢Â€Â“/g, "-")
    .replace(/Ã/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function rowToText(row, file) {
  const ignoreKeys = new Set([
    "lat", "log", "latitude", "longitude", "url", "website_status",
    "address_1", "city_clean", "source", "intent", "pro", "catag", "__empty", "__empty_1"
  ]);
  const parts = [];

  for (const [k, v] of Object.entries(row)) {
    if (v === null || v === undefined || v === "") continue;
    const cleanK = k.trim();
    const lowerK = cleanK.toLowerCase();
    if (ignoreKeys.has(lowerK)) continue;
    const cleanV = cleanValue(String(v));
    if (cleanV) parts.push(`${cleanK}: ${cleanV}`);
  }

  const lowerFile = file.toLowerCase();
  if (lowerFile.includes("restaurant") || lowerFile.includes("food")) {
    parts.push("Category: Restaurant / Food Spot");
  } else if (lowerFile.includes("hotel")) {
    parts.push("Category: Hotel / Accommodation");
  } else if (lowerFile.includes("hospital") || lowerFile.includes("medical")) {
    parts.push("Category: Medical / Hospital");
  } else if (lowerFile.includes("tourist") || lowerFile.includes("historical")) {
    parts.push("Category: Tourist Attraction / Historical Place");
  }

  return parts.join("\n");
}

function tokenize(text) {
  const rawWords = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOP_WORDS.has(t));

  const expandedTokens = [];
  for (const word of rawWords) {
    expandedTokens.push(word);
    // Add stemmed / synonym tokens if available
    if (SYNONYM_MAP[word]) {
      expandedTokens.push(...SYNONYM_MAP[word]);
    } else if (word.endsWith("s") && word.length > 3) {
      const singular = word.slice(0, -1);
      expandedTokens.push(singular);
      if (SYNONYM_MAP[singular]) {
        expandedTokens.push(...SYNONYM_MAP[singular]);
      }
    }
  }

  return expandedTokens;
}

function buildTf(tokens) {
  const tf = new Map();
  for (const t of tokens) tf.set(t, (tf.get(t) || 0) + 1);
  const len = tokens.length || 1;
  for (const [k, v] of tf) tf.set(k, v / len);
  return tf;
}

function cosineSim(tfA, tfB, idf) {
  let dot = 0, normA = 0, normB = 0;
  for (const [term, wA] of tfA) {
    const idfVal = idf.get(term) || 0;
    const wAi = wA * idfVal;
    const wBi = (tfB.get(term) || 0) * idfVal;
    dot   += wAi * wBi;
    normA += wAi * wAi;
  }
  for (const [term, wB] of tfB) {
    const idfVal = idf.get(term) || 0;
    normB += (wB * idfVal) ** 2;
  }
  if (!normA || !normB) return 0;
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// ── File loading ──────────────────────────────────────────────────────────────

function findDataDirectory() {
  const candidatePaths = [
    path.resolve(__dirname, "../data"),
    path.resolve(__dirname, "../../data"),
    path.resolve(process.cwd(), "src/data"),
    path.resolve(process.cwd(), "data"),
    path.resolve(process.cwd(), "Alam's/agentra-backend/src/data"),
    path.resolve(process.cwd(), "Alam's/agentra-backend/data"),
  ];

  for (const candidate of candidatePaths) {
    if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
      const files = fs.readdirSync(candidate).filter((f) => {
        const ext = path.extname(f).toLowerCase();
        return ext === ".xlsx" || ext === ".xls" || ext === ".csv";
      });
      if (files.length > 0) {
        return { dataDir: candidate, files, searchedPaths: candidatePaths };
      }
    }
  }

  const defaultDir = path.resolve(__dirname, "../data");
  return {
    dataDir: defaultDir,
    files: fs.existsSync(defaultDir)
      ? fs.readdirSync(defaultDir).filter((f) => {
          const ext = path.extname(f).toLowerCase();
          return ext === ".xlsx" || ext === ".xls" || ext === ".csv";
        })
      : [],
    searchedPaths: candidatePaths,
  };
}

function loadExcelDocuments() {
  const { dataDir, files, searchedPaths } = findDataDirectory();
  const rawDocs = [];

  if (!fs.existsSync(dataDir) || files.length === 0) {
    console.error("❌ CRITICAL ERROR [RAG Service]: /data directory or valid dataset files (.csv, .xlsx, .xls) missing!");
    return { rawDocs: [], fileCount: 0, dataDir };
  }

  console.log(`📁 Loading RAG datasets from directory: ${dataDir}`);

  for (const file of files) {
    const filePath = path.join(dataDir, file);
    let rows = [];

    try {
      const workbook = XLSX.readFile(filePath, { type: "file" });
      for (const sheetName of workbook.SheetNames) {
        rows = rows.concat(XLSX.utils.sheet_to_json(workbook.Sheets[sheetName]));
      }

      let fileChunks = 0;
      const lowerFile = file.toLowerCase();
      const isMurree = lowerFile.includes("murree");
      const isLahore = lowerFile.includes("lahore");
      const isFaq = lowerFile.includes("faq");

      let fileCategory = "other";
      if (lowerFile.includes("restaurant") || lowerFile.includes("food")) fileCategory = "food";
      else if (lowerFile.includes("hotel")) fileCategory = "hotel";
      else if (lowerFile.includes("hospital") || lowerFile.includes("medical")) fileCategory = "medical";
      else if (lowerFile.includes("historical") || lowerFile.includes("tourist")) fileCategory = "attraction";

      for (const row of rows) {
        const content = rowToText(row, file);
        const lowerContent = content.toLowerCase();
        if (lowerContent.startsWith("name: lahore") && lowerContent.split("\n").length <= 3) {
          continue;
        }

        if (content.trim()) {
          rawDocs.push({
            file: lowerFile,
            city: isMurree ? "murree" : (isLahore ? "lahore" : "both"),
            isFaq,
            fileCategory,
            text: content,
          });
          fileChunks++;
        }
      }
      console.log(`📄 Loaded ${fileChunks} chunks from: ${file}`);
    } catch (err) {
      console.error(`❌ Error parsing file ${file}:`, err.message);
    }
  }

  return { rawDocs, fileCount: files.length, dataDir };
}

// ── Public API ────────────────────────────────────────────────────────────────

async function initVectorStore() {
  if (_docs) {
    return { success: true, count: _docs.length, fileCount: 0, alreadyInitialized: true };
  }

  console.log("🔧 Building lightweight keyword index from data files...");

  const { rawDocs, fileCount, dataDir } = loadExcelDocuments();

  if (rawDocs.length === 0) {
    const errorMsg = `❌ RAG Initialization Failed: No valid dataset files found in (${dataDir}).`;
    console.error(errorMsg);
    throw new Error(errorMsg);
  }

  _docs = rawDocs.map((doc) => ({
    text: doc.text,
    file: doc.file,
    city: doc.city,
    isFaq: doc.isFaq,
    fileCategory: doc.fileCategory,
    tokens: buildTf(tokenize(doc.text)),
  }));

  const df  = new Map();
  const N   = _docs.length;
  for (const doc of _docs) {
    for (const term of doc.tokens.keys()) {
      df.set(term, (df.get(term) || 0) + 1);
    }
  }
  _idf = new Map();
  for (const [term, freq] of df) {
    _idf.set(term, Math.log((N + 1) / (freq + 1)) + 1);
  }

  console.log(`✅ Keyword index ready — ${_docs.length} document chunks indexed from ${fileCount} data files.`);
  return { success: true, count: _docs.length, fileCount, dataDir };
}

/**
 * Retrieve the top-k most relevant document chunks for a query.
 */
async function retrieveExcelContext(query, k = 10, historyContext = "") {
  if (!_docs) await initVectorStore();

  const combinedQuery = `${historyContext} ${query}`.trim();
  const qLower = combinedQuery.toLowerCase();
  const qTokens = buildTf(tokenize(combinedQuery));

  const isQueryMurree = qLower.includes("murree");
  const isQueryLahore = qLower.includes("lahore");

  const isFoodQuery = /\b(restaurant|restaurants|resturant|resturants|food|eat|eating|dining|cafe|cafes|dhaba|dhabas|karahi|bbq|dish|dishes|cuisine|spot|spots|eatery|eateries)\b/i.test(qLower);
  const isHotelQuery = /\b(hotel|hotels|hostel|hostels|stay|staying|accommodation|lodge|lodging|resort|resorts|motel|motels|guest|guesthouse|guesthouses|inn|inns)\b/i.test(qLower);
  const isHospitalQuery = /\b(hospital|hospitals|medical|doctor|doctors|clinic|clinics|emergency|health)\b/i.test(qLower);
  const isAttractionQuery = /\b(place|places|spot|spots|visit|visiting|attraction|attractions|tourist|sightseeing|monument|fort|park)\b/i.test(qLower);

  const scored = _docs.map((doc) => {
    let score = cosineSim(qTokens, doc.tokens, _idf);

    // City relevance boost
    if (isQueryMurree) {
      if (doc.city === "murree") score *= 4.0;
      else if (doc.city === "lahore") score *= 0.05;
    } else if (isQueryLahore) {
      if (doc.city === "lahore") score *= 4.0;
      else if (doc.city === "murree") score *= 0.05;
    }

    // Category boost over FAQ datasets
    if (isFoodQuery) {
      if (doc.fileCategory === "food") score *= 10.0;
      if (doc.isFaq) score *= 0.2;
    }
    if (isHotelQuery) {
      if (doc.fileCategory === "hotel") score *= 10.0;
      if (doc.isFaq) score *= 0.2;
    }
    if (isHospitalQuery) {
      if (doc.fileCategory === "medical") score *= 10.0;
      if (doc.isFaq) score *= 0.2;
    }
    if (isAttractionQuery) {
      if (doc.fileCategory === "attraction") score *= 10.0;
      if (doc.isFaq) score *= 0.2;
    }

    return {
      text: doc.text,
      score,
      fileCategory: doc.fileCategory,
      city: doc.city,
      isFaq: doc.isFaq
    };
  });

  scored.sort((a, b) => b.score - a.score);

  // Fallback Intent Retrieval: If top scores are weak or 0, fallback to direct category matches
  const topResults = [];
  const seenTexts = new Set();

  for (const r of scored) {
    if (r.score > 0.001) {
      const cleanSnippet = r.text.toLowerCase().replace(/\s+/g, " ").substring(0, 60);
      if (!seenTexts.has(cleanSnippet)) {
        seenTexts.add(cleanSnippet);
        topResults.push(r.text);
      }
    }
    if (topResults.length >= k) break;
  }

  // If topResults is still under k, backfill with high-quality category items
  if (topResults.length < 5) {
    let targetCategory = null;
    if (isFoodQuery) targetCategory = "food";
    else if (isHotelQuery) targetCategory = "hotel";
    else if (isHospitalQuery) targetCategory = "medical";
    else if (isAttractionQuery) targetCategory = "attraction";

    const candidateDocs = _docs.filter((d) => {
      if (targetCategory && d.fileCategory !== targetCategory) return false;
      if (isQueryMurree && d.city === "lahore") return false;
      if (isQueryLahore && d.city === "murree") return false;
      return !d.isFaq;
    });

    for (const d of candidateDocs) {
      const cleanSnippet = d.text.toLowerCase().replace(/\s+/g, " ").substring(0, 60);
      if (!seenTexts.has(cleanSnippet)) {
        seenTexts.add(cleanSnippet);
        topResults.push(d.text);
      }
      if (topResults.length >= k) break;
    }
  }

  return topResults.slice(0, k).join("\n\n---\n\n");
}

module.exports = { initVectorStore, retrieveExcelContext };
