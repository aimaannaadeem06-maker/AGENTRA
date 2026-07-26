/**
 * rag.service.js — lightweight keyword-based RAG (no ONNX / no heavy ML model).
 *
 * Why: The HuggingFace Transformers embedding model (Xenova/all-MiniLM-L6-v2)
 * requires ~735 MB of RAM and crashes the server on low-memory machines.
 * We replace it with a simple TF-IDF cosine-similarity search that is
 * functionally equivalent for short CSV/Excel rows and uses < 5 MB of RAM.
 *
 * The public API (initVectorStore, retrieveExcelContext) is unchanged so
 * chatbot.controller.js needs no edits.
 */const XLSX = require("xlsx");
const path = require("path");
const fs   = require("fs");

// ── In-memory document store ──────────────────────────────────────────────────
let _docs   = null;   // Array<{ text: string, file: string, city: string, isFaq: boolean, fileCategory: string, tokens: Map<string,number> }>
let _idf    = null;   // Map<string, number>

// ── Helpers ───────────────────────────────────────────────────────────────────

const STOP_WORDS = new Set([
  "the", "a", "an", "in", "on", "of", "to", "is", "are", "was", "were", "be",
  "what", "where", "how", "when", "which", "who", "tell", "me", "about",
  "list", "down", "any", "some", "for", "with", "and", "or", "from", "at", "by", "show", "give"
]);

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
  }

  return parts.join("\n");
}

function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOP_WORDS.has(t));
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
    console.error(`📍 Working Directory (process.cwd()): ${process.cwd()}`);
    console.error(`📍 Service Directory (__dirname): ${__dirname}`);
    console.error("📍 Searched Candidate Paths:", searchedPaths || [dataDir]);
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
        // Skip incomplete or garbage rows where Name is just 'Lahore' or 'Murree'
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

/**
 * Build the in-memory TF-IDF index (called once at startup).
 * Safe to call multiple times — subsequent calls return existing status.
 */
async function initVectorStore() {
  if (_docs) {
    return { success: true, count: _docs.length, fileCount: 0, alreadyInitialized: true };
  }

  console.log("🔧 Building lightweight keyword index from data files...");

  const { rawDocs, fileCount, dataDir } = loadExcelDocuments();

  if (rawDocs.length === 0) {
    const errorMsg = `❌ RAG Initialization Failed: No valid dataset files (.csv, .xlsx, .xls) found or parsed in data directory (${dataDir}).`;
    console.error(errorMsg);
    throw new Error(errorMsg);
  }

  // Tokenise every document
  _docs = rawDocs.map((doc) => ({
    text: doc.text,
    file: doc.file,
    city: doc.city,
    isFaq: doc.isFaq,
    fileCategory: doc.fileCategory,
    tokens: buildTf(tokenize(doc.text)),
  }));

  // Compute IDF across the corpus
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

  const logMessage = `✅ Keyword index ready — ${_docs.length} document chunks indexed from ${fileCount} data files.`;
  console.log(logMessage);
  return { success: true, count: _docs.length, fileCount, dataDir };
}

/**
 * Retrieve the top-k most relevant document chunks for a query.
 * Returns a single string (chunks joined by separators).
 */
async function retrieveExcelContext(query, k = 10) {
  // Lazy init in case initVectorStore wasn't called at startup
  if (!_docs) await initVectorStore();

  const qLower = query.toLowerCase();
  const qTokens = buildTf(tokenize(query));

  const isQueryMurree = qLower.includes("murree");
  const isQueryLahore = qLower.includes("lahore");

  const isFoodQuery = /\b(restaurant|restaurants|food|eat|eating|dining|cafe|cafes|dhaba|dhabas|karahi|bbq|dish|dishes|cuisine|spot|spots|eatery|eateries)\b/i.test(query);
  const isHotelQuery = /\b(hotel|hotels|stay|staying|accommodation|lodge|lodging|resort|resorts|motel|motels|guest|guesthouse|guesthouses|inn|inns)\b/i.test(query);
  const isHospitalQuery = /\b(hospital|hospitals|medical|doctor|doctors|clinic|emergency|health)\b/i.test(query);
  const isAttractionQuery = /\b(place|places|spot|spots|visit|visiting|attraction|attractions|tourist|sightseeing|monument|fort|park)\b/i.test(query);

  const scored = _docs.map((doc) => {
    let score = cosineSim(qTokens, doc.tokens, _idf);

    // City relevance boost & strong cross-city penalty
    if (isQueryMurree) {
      if (doc.city === "murree") score *= 3.0;
      else if (doc.city === "lahore") score *= 0.01;
    } else if (isQueryLahore) {
      if (doc.city === "lahore") score *= 3.0;
      else if (doc.city === "murree") score *= 0.01;
    }

    // Entity dataset boost over FAQ datasets
    if (isFoodQuery) {
      if (doc.fileCategory === "food") score *= 8.0;
      if (doc.isFaq) score *= 0.1;
    }
    if (isHotelQuery) {
      if (doc.fileCategory === "hotel") score *= 8.0;
      if (doc.isFaq) score *= 0.1;
    }
    if (isHospitalQuery) {
      if (doc.fileCategory === "medical") score *= 8.0;
      if (doc.isFaq) score *= 0.1;
    }
    if (isAttractionQuery) {
      if (doc.fileCategory === "attraction") score *= 8.0;
      if (doc.isFaq) score *= 0.1;
    }

    return {
      text: doc.text,
      score,
    };
  });

  scored.sort((a, b) => b.score - a.score);

  // Deduplicate results
  const seenTexts = new Set();
  const uniqueResults = [];

  for (const r of scored) {
    const cleanSnippet = r.text.toLowerCase().replace(/\s+/g, " ").substring(0, 60);
    if (!seenTexts.has(cleanSnippet)) {
      seenTexts.add(cleanSnippet);
      uniqueResults.push(r.text);
    }
    if (uniqueResults.length >= k) break;
  }

  return uniqueResults.join("\n\n---\n\n");
}

module.exports = { initVectorStore, retrieveExcelContext };
