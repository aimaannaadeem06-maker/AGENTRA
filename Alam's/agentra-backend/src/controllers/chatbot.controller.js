// controllers/chatbot.controller.js
const Groq = require("groq-sdk");
const { retrieveExcelContext, initVectorStore } = require("../services/rag.service");
const { fetchRelevantPackages, fetchPackagesForDisplay } = require("../services/packages.service");

const sessionStore = new Map();
const SESSION_TTL_MS = 30 * 60 * 1000;

setInterval(() => {
  const now = Date.now();
  for (const [id, session] of sessionStore.entries()) {
    if (now - session.lastActive > SESSION_TTL_MS) sessionStore.delete(id);
  }
}, 10 * 60 * 1000);

const SYSTEM_PROMPT = `You are Alex, a friendly, accurate, and helpful travel assistant for the Agentra travel app.

CRITICAL GROUNDING RULES (100% STRICT RAG COMPLIANCE):
1. You MUST answer user questions ONLY using the exact facts, places, hotels, restaurants, phone numbers, and details provided in the KNOWLEDGE BASE section below.
2. DO NOT use outside knowledge, web information, or unmentioned facts under any circumstances.
3. If the requested information, place, or detail is NOT present in the KNOWLEDGE BASE below, you MUST reply with a polite message such as: "I don't have information on that in my current database. Would you like to know about available restaurants, hotels, or spots in Murree or Lahore?"
4. NEVER invent or assume prices, phone numbers, addresses, or details that are not in the KNOWLEDGE BASE.
5. You ONLY cover Murree and Lahore (cities in Pakistan). If asked about any other city or country, state clearly that you only cover Murree and Lahore.

KNOWLEDGE BASE (Authoritative Data from Datasets):
{excelContext}

LIVE TRAVEL PACKAGES:
{packageContext}`;

const OUT_OF_SCOPE_TERMS = [
  "karachi", "islamabad", "peshawar", "quetta", "faisalabad", "multan",
  "rawalpindi", "dubai", "london", "paris", "new york", "india", "turkey",
  "bangkok", "europe", "america", "abroad", "international", "overseas",
  "skardu", "gilgit", "hunza", "swat", "naran", "kaghan", "chitral",
];

const GENERAL_PHRASES = [
  "hello", "hi", "help", "what can you", "who are you", "how are you",
  "salam", "assalam", "aoa", "kya hal",
];

const PACKAGE_KEYWORDS = [
  "package", "packages", "tour", "trip", "book", "deal", "offer",
];

function isOutOfScope(query) {
  const q = query.toLowerCase();
  if (GENERAL_PHRASES.some((p) => q.includes(p))) return false;
  const mentionsMurree = q.includes("murree");
  const mentionsLahore = q.includes("lahore");
  const mentionsOther = OUT_OF_SCOPE_TERMS.some((t) => q.includes(t));
  return mentionsOther && !mentionsMurree && !mentionsLahore;
}

function isPackageQuery(query) {
  return PACKAGE_KEYWORDS.some((kw) => query.toLowerCase().includes(kw));
}

function getSession(sessionId) {
  if (!sessionStore.has(sessionId)) {
    sessionStore.set(sessionId, { messages: [], lastActive: Date.now() });
  }
  const session = sessionStore.get(sessionId);
  session.lastActive = Date.now();
  return session;
}

function detectLanguage(message) {
  const urduScriptPattern = /[\u0600-\u06FF]/;
  if (urduScriptPattern.test(message)) return "URDU_SCRIPT";

  const romanUrduTerms = new Set([
    "kya", "kaise", "kese", "kaha", "kahan", "kyun", "kyu", "matlab",
    "batao", "bataen", "bataye", "batayen", "chahiye", "chahye",
    "mujhe", "mjhe", "humein", "humain", "hamain", "apna", "apne", "apni",
    "hain", "hoga", "hogi", "hoge", "hote", "hoti", "hota",
    "raha", "rahi", "rahe", "shukriya", "shukria", "meherbani",
    "karo", "karna", "karni", "karne", "bhai", "jaan", "yaar", "yar",
    "konsa", "konsi", "konse", "gaye", "gaya", "gayi", "wale", "wali", "wala",
    "kitna", "kitni", "kitne", "sabse", "sasta", "sasti", "saste",
    "achha", "achi", "ache", "behtreen", "jagah", "jayein", "jaye"
  ]);

  const words = message.toLowerCase().replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter(Boolean);

  let romanUrduMatches = 0;
  for (const word of words) {
    if (romanUrduTerms.has(word)) romanUrduMatches++;
  }

  const romanUrduPhrasePattern = /\b(kya|kaisa|kese|kahan|konsa|kon sa|mujhe|batao|kaun|kaise)\s+(hai|hay|hy|he|hain|bhi|hoon|ho)\b/i;
  if (romanUrduPhrasePattern.test(message)) romanUrduMatches += 2;

  // If there are distinctive Roman Urdu words or phrases, return ROMAN_URDU; otherwise default strictly to ENGLISH!
  if (romanUrduMatches >= 2) {
    return "ROMAN_URDU";
  }

  return "ENGLISH";
}

async function initializeRAG(req, res) {
  try {
    await initVectorStore();
    return res.json({ success: true, message: "RAG pipeline initialized." });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

async function chat(req, res) {
  try {
    const { message, sessionId } = req.body;

    if (!message || typeof message !== "string" || message.trim() === "") {
      return res.status(400).json({ error: "message field is required." });
    }

    const sid = sessionId || `session_${Date.now()}_${Math.random().toString(36).slice(2)}`;

    // Out-of-scope guard
    if (isOutOfScope(message)) {
      return res.json({
        sessionId: sid,
        reply: "I'm sorry, I can only help with travel information about Murree and Lahore. Ask me anything about these two cities and I'll be happy to help! 😊",
        packages: [],
      });
    }

    const session = getSession(sid);
    const history = session.messages.slice(-6);
    const historyText = history.map((m) => m.content).join(" ");

    // Only fetch packages if user asks AND mentions Murree or Lahore
    const mentionsMurree = message.toLowerCase().includes("murree") || historyText.toLowerCase().includes("murree");
    const mentionsLahore = message.toLowerCase().includes("lahore") || historyText.toLowerCase().includes("lahore");
    const mentionsAllowedCity = mentionsMurree || mentionsLahore;
    const shouldFetchPackages = isPackageQuery(message) && mentionsAllowedCity;

    const [excelContext, packageContext, displayPackages] = await Promise.all([
      retrieveExcelContext(message, 10, historyText),
      shouldFetchPackages ? fetchRelevantPackages(message) : Promise.resolve(null),
      shouldFetchPackages ? fetchPackagesForDisplay(message) : Promise.resolve([]),
    ]);

    const filledPrompt = SYSTEM_PROMPT
      .replace("{excelContext}", excelContext || "No relevant data found.")
      .replace("{packageContext}", packageContext || "No matching packages found.");

    const lang = detectLanguage(message);
    let languageInstruction = "";

    if (lang === "URDU_SCRIPT") {
      languageInstruction = "CRITICAL: The user's query is in Urdu script. You MUST reply exclusively in Urdu script.";
    } else if (lang === "ROMAN_URDU") {
      languageInstruction = "CRITICAL: The user's query is in Roman Urdu. You MUST reply exclusively in Roman Urdu (Urdu written in Latin letters).";
    } else {
      languageInstruction = "CRITICAL: The user's query is in standard English. You MUST reply exclusively in standard English. Do NOT use Roman Urdu or Urdu script.";
    }

    const apiMessages = [
      {
        role: "system",
        content: `${filledPrompt}\n\n====================\nLANGUAGE DIRECTIVE: ${languageInstruction}\n====================`
      },
      ...history.map((m) => ({
        role: m.role === "assistant" ? "assistant" : "user",
        content: m.content
      })),
      {
        role: "user",
        content: `${message}\n\n[INSTRUCTION: Answer strictly using facts from KNOWLEDGE BASE. Reply in ${lang === "ROMAN_URDU" ? "Roman Urdu" : lang === "URDU_SCRIPT" ? "Urdu script" : "English"}]`
      }
    ];

    const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
    const completion = await groq.chat.completions.create({
      model: "llama-3.3-70b-versatile",
      messages: apiMessages,
      temperature: 0.1, // Factual generation, zero hallucination
    });

    const reply = completion.choices[0]?.message?.content?.trim() || "Sorry, I could not generate a response.";

    session.messages.push({ role: "user", content: message });
    session.messages.push({ role: "assistant", content: reply });

    return res.json({ sessionId: sid, reply, packages: displayPackages });
  } catch (err) {
    console.error("Chat error:", err);
    return res.status(500).json({
      error: "Something went wrong. Please try again.",
      ...(process.env.NODE_ENV === "development" && { details: err.message }),
    });
  }
}

module.exports = { chat, initializeRAG, detectLanguage };
