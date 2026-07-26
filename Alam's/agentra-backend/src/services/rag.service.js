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
 */

const XLSX = require("xlsx");
const path = require("path");
const fs   = require("fs");

// ── In-memory document store ──────────────────────────────────────────────────
let _docs   = null;   // Array<{ text: string, tokens: Map<string,number> }>
let _idf    = null;   // Map<string, number>

// ── Helpers ───────────────────────────────────────────────────────────────────

function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
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
  const texts = [];

  if (!fs.existsSync(dataDir) || files.length === 0) {
    console.error("❌ CRITICAL ERROR [RAG Service]: /data directory or valid dataset files (.csv, .xlsx, .xls) missing!");
    console.error(`📍 Working Directory (process.cwd()): ${process.cwd()}`);
    console.error(`📍 Service Directory (__dirname): ${__dirname}`);
    console.error("📍 Searched Candidate Paths:", searchedPaths || [dataDir]);
    return { texts: [], fileCount: 0, dataDir };
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
      for (const row of rows) {
        const content = Object.entries(row)
          .map(([k, v]) => `${k}: ${v}`)
          .join("\n");
        if (content.trim()) {
          texts.push(content);
          fileChunks++;
        }
      }
      console.log(`📄 Loaded ${fileChunks} chunks from: ${file}`);
    } catch (err) {
      console.error(`❌ Error parsing file ${file}:`, err.message);
    }
  }

  return { texts, fileCount: files.length, dataDir };
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

  const { texts, fileCount, dataDir } = loadExcelDocuments();

  if (texts.length === 0) {
    const errorMsg = `❌ RAG Initialization Failed: No valid dataset files (.csv, .xlsx, .xls) found or parsed in data directory (${dataDir}).`;
    console.error(errorMsg);
    throw new Error(errorMsg);
  }

  // Tokenise every document
  _docs = texts.map((text) => ({ text, tokens: buildTf(tokenize(text)) }));

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
async function retrieveExcelContext(query, k = 5) {
  // Lazy init in case initVectorStore wasn't called at startup
  if (!_docs) await initVectorStore();

  const qTokens = buildTf(tokenize(query));

  const scored = _docs.map((doc) => ({
    text:  doc.text,
    score: cosineSim(qTokens, doc.tokens, _idf),
  }));

  scored.sort((a, b) => b.score - a.score);

  return scored
    .slice(0, k)
    .map((r) => r.text)
    .join("\n\n---\n\n");
}

module.exports = { initVectorStore, retrieveExcelContext };
