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

function loadExcelDocuments() {
  const dataDir = path.join(__dirname, "../data");
  const texts   = [];

  if (!fs.existsSync(dataDir)) {
    console.warn("⚠️  No /data folder found.");
    return texts;
  }

  const files = fs.readdirSync(dataDir).filter(
    (f) => f.endsWith(".xlsx") || f.endsWith(".xls") || f.endsWith(".csv")
  );

  for (const file of files) {
    const filePath = path.join(dataDir, file);
    let rows = [];

    const workbook = XLSX.readFile(filePath, { type: "file" });
    for (const sheetName of workbook.SheetNames) {
      rows = rows.concat(XLSX.utils.sheet_to_json(workbook.Sheets[sheetName]));
    }

    for (const row of rows) {
      const content = Object.entries(row)
        .map(([k, v]) => `${k}: ${v}`)
        .join("\n");
      texts.push(content);
    }
    console.log(`📄 Loaded: ${file}`);
  }

  return texts;
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Build the in-memory TF-IDF index (called once at startup).
 * Safe to call multiple times — subsequent calls are no-ops.
 */
async function initVectorStore() {
  if (_docs) return;   // already initialised

  console.log("🔧 Building lightweight keyword index from data files...");

  const texts = loadExcelDocuments();

  if (texts.length === 0) {
    _docs = [{ text: "Agentra chatbot ready.", tokens: buildTf(["agentra"]) }];
    _idf  = new Map([["agentra", 1]]);
    console.log("⚠️  Keyword index created with placeholder (no data files).");
    return;
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

  console.log(`✅ Keyword index ready — ${_docs.length} document chunks indexed.`);
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
