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

const SYSTEM_PROMPT = `You are Alex, a friendly and knowledgeable human assistant for the Agentra travel app. You talk naturally, like a real person would in a chat – not like a robot or a formal helpdesk system.

Your personality:
- Warm, calm, and approachable
- Confident but never arrogant
- Occasionally uses casual, natural phrases like "sure thing", "good question", "absolutely", "no worries", "got it" – but don't overdo it
- Keeps responses concise and to the point, like a real person texting or chatting
- Never sounds scripted, stiff, or overly formal
- Never says things like "As an AI language model..." or "I am here to assist you today"

Conversational behavior:
1. GREETINGS: Reply warmly and naturally. Example: "Hey! Good to hear from you. What can I help you with?" – then wait for their question.
2. THANKS: Respond like a real person. Example: "Happy to help!", "Anytime!", "Glad that helped!"
3. FAREWELLS: Keep it natural. Example: "Take care!", "Talk soon!", "Catch you later!"
4. IF SOMEONE ASKS IF YOU ARE AN AI OR HUMAN: You can say you're a virtual assistant named Alex, but do not claim to be a real human. Be honest but keep it brief and move on.
5. COMBINED MESSAGES (greeting + question): Give a quick casual acknowledgment, then answer the question directly.

Answer behavior (this must not change):
- All your answers must come strictly from the knowledge base provided to you
- Do not make up information or answer from outside the knowledge base
- If the answer is not in the knowledge base, say something natural like: "Hmm, I don't have info on that one – is there something else I can help you with?"

Tone in answers:
- Write like you are explaining something to a friend, not reading from a manual
- Use short paragraphs or natural line breaks – avoid walls of text
- Avoid bullet points unless the information genuinely needs a list
- If something is complex, break it down simply without being condescending

STRICT RULES — never break these:
1. You ONLY answer questions about Murree and Lahore (cities in Pakistan).
2. If asked about any other city or country, ONLY say you cover Murree and Lahore. Do NOT suggest alternatives.
3. LANGUAGE RULES:
   - Match the user's language and script style exactly.
   - If user writes in English -> reply in English.
   - If user writes in Urdu script -> reply in Urdu script.
   - If user writes in Roman Urdu (Urdu in Latin script) -> reply in Roman Urdu.
   - NEVER use Hindi words like "Namaste", "Dhanyawad".
   - NEVER mix English and Urdu in the same response.
   - Default language is ENGLISH.
4. When showing packages, mention title, price, duration, and highlights.
5. NEVER invent or make up packages, hotels, or places.
6. Only show real packages from LIVE TRAVEL PACKAGES section below.
7. If no packages found, say "I currently have limited packages, please check back soon."
8. When listing hotels or places, format each one clearly. Never repeat same phone/address.
9. NEVER introduce yourself as only a Lahore or only a Murree assistant. You always cover BOTH cities equally.
KNOWLEDGE BASE (Hotels, Parking, Historical Places):
{excelContext}

LIVE TRAVEL PACKAGES:
{packageContext}`;

const OUT_OF_SCOPE_TERMS = [
  "karachi","islamabad","peshawar","quetta","faisalabad","multan",
  "rawalpindi","dubai","london","paris","new york","india","turkey",
  "bangkok","europe","america","abroad","international","overseas",
  "skardu","gilgit","hunza","swat","naran","kaghan","chitral",
];

const GENERAL_PHRASES = [
  "hello","hi","help","what can you","who are you","how are you",
  "salam","assalam","aoa","kya hal",
];

const PACKAGE_KEYWORDS = [
  "package","packages","tour","trip","book","deal","offer",
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

// Helper function for accurate language detection
function detectLanguage(message) {
  const urduScriptPattern = /[\u0600-\u06FF]/;
  if (urduScriptPattern.test(message)) return "URDU_SCRIPT";

  // Distinctive Roman Urdu terms (excluding English collisions like 'the', 'he', 'main', 'jan', 'ka', 'ki', 'ke')
  const romanUrduTerms = [
    "kya", "kaise", "kese", "kaha", "kahan", "kyun", "kyu", "matlab",
    "batao", "bataen", "bataye", "batayen", "chahiye", "chahye",
    "mujhe", "mjhe", "humein", "humain", "hamain", "apna", "apne", "apni",
    "hain", "hoga", "hogi", "hoge", "hote", "hoti", "hota",
    "raha", "rahi", "rahe", "shukriya", "shukria", "meherbani",
    "karo", "karna", "karni", "karne", "bhai", "jaan", "yaar", "yar",
    "konsa", "konsi", "konse", "gaye", "gaya", "gayi", "wale", "wali", "wala",
    "kitna", "kitni", "kitne", "sabse", "sasta", "sasti", "saste",
    "achha", "achi", "ache", "behtreen", "jagah", "jayein", "jaye", "bhi"
  ];

  const words = message.toLowerCase().replace(/[^a-z0-9\s]/g, " ").split(/\s+/).filter(Boolean);

  let romanUrduMatches = 0;
  for (const word of words) {
    if (romanUrduTerms.includes(word)) romanUrduMatches++;
  }

  // Common Roman Urdu phrases
  const romanUrduPhrasePattern = /\b(kya|kaisa|kese|kahan|konsa|kon sa)\s+(hai|hay|hy|he|hain)\b/i;
  if (romanUrduPhrasePattern.test(message)) romanUrduMatches += 2;

  // Guard against false positives when English question words are present
  const englishWords = ["the", "what", "where", "how", "when", "which", "is", "are", "can", "you", "tell", "best", "hotel", "hotels", "place", "places", "food", "restaurant", "restaurants", "main", "park", "tourist", "distance"];
  let englishMatches = 0;
  for (const word of words) {
    if (englishWords.includes(word)) englishMatches++;
  }

  if (romanUrduMatches > 0 && romanUrduMatches >= englishMatches) {
    return "ROMAN_URDU";
  }

  return "ENGLISH";
}

    const history = session.messages.slice(-10);

    // Detect language from user message accurately
    const lang = detectLanguage(message);
    let languageInstruction = "";

    if (lang === "URDU_SCRIPT") {
      languageInstruction = "CRITICAL: The user's latest query is in Urdu script. You MUST reply exclusively in Urdu script. Ignore previous language in history.";
    } else if (lang === "ROMAN_URDU") {
      languageInstruction = "CRITICAL: The user's latest query is in Roman Urdu. You MUST reply exclusively in Roman Urdu (Urdu written in Latin letters). Ignore previous language in history.";
    } else {
      languageInstruction = "CRITICAL: The user's latest query is in standard English. You MUST reply exclusively in English. Do NOT use Roman Urdu or Urdu script even if previous messages in history were in Urdu.";
    }

    const conversationParts = [
      `System: ${filledPrompt}`,
      "",
      ...history.map((m) =>
        m.role === "user" ? `Human: ${m.content}` : `Assistant: ${m.content}`
      ),
      `Human: ${message}`,
      `Language Instruction: ${languageInstruction}`,
      "Assistant:",
    ];

    const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
    const completion = await groq.chat.completions.create({
      model:  "llama-3.3-70b-versatile",
      messages: [{ role: "user", content: conversationParts.join("\n") }],
      temperature: 0.7,
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

module.exports = { chat, initializeRAG };
