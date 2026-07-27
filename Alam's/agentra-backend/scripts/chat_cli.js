/**
 * chat_cli.js — Interactive Terminal Tester for Agentra Chatbot RAG Pipeline
 *
 * Usage:
 *   node scripts/chat_cli.js              (Tests live Render backend)
 *   node scripts/chat_cli.js --local      (Tests local RAG & Groq directly)
 */
const readline = require("readline");
const http = require("https");
const dotenv = require("dotenv");
dotenv.config();

const isLocal = process.argv.includes("--local");
const SERVER_URL = isLocal ? "http://localhost:5000" : "https://agentra-backend.onrender.com";

console.log("\n=======================================================");
console.log(`🤖 AGENTRA CHATBOT TERMINAL TESTER`);
console.log(`📍 Testing Mode: ${isLocal ? "LOCAL RAG & GROQ" : "LIVE RENDER BACKEND (" + SERVER_URL + ")"}`);
console.log("=======================================================");
console.log("Type your questions below (or type 'exit' to quit):\n");

if (isLocal) {
  runLocalCli();
} else {
  runRemoteCli();
}

function runRemoteCli() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const sessionId = `cli_test_${Date.now()}`;

  function ask() {
    rl.question("👤 You: ", async (input) => {
      const query = input.trim();
      if (!query || query.toLowerCase() === "exit") {
        console.log("👋 Bye!");
        rl.close();
        process.exit(0);
      }

      try {
        console.log("⏳ Waiting for bot response...");
        const postData = JSON.stringify({ message: query, sessionId });

        const req = http.request(`${SERVER_URL}/api/chatbot/message`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(postData)
          }
        }, (res) => {
          let data = "";
          res.on("data", (chunk) => { data += chunk; });
          res.on("end", () => {
            try {
              const json = JSON.parse(data);
              console.log(`\n🤖 Alex: ${json.reply || json.error || data}`);
            } catch (e) {
              console.log(`\n🤖 Response: ${data}`);
            }
            console.log("\n-------------------------------------------------------");
            ask();
          });
        });

        req.on("error", (err) => {
          console.error(`❌ Request Error: ${err.message}`);
          console.log("\n-------------------------------------------------------");
          ask();
        });

        req.write(postData);
        req.end();
      } catch (err) {
        console.error("❌ Error:", err.message);
        ask();
      }
    });
  }

  ask();
}

async function runLocalCli() {
  const { initVectorStore } = require("../src/services/rag.service");
  const { chat } = require("../src/controllers/chatbot.controller");

  console.log("🔧 Initializing local RAG index...");
  await initVectorStore();
  console.log("✅ Local RAG ready!\n");

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const sessionId = `cli_local_${Date.now()}`;

  function ask() {
    rl.question("👤 You: ", async (input) => {
      const query = input.trim();
      if (!query || query.toLowerCase() === "exit") {
        console.log("👋 Bye!");
        rl.close();
        process.exit(0);
      }

      const req = { body: { message: query, sessionId } };
      const res = {
        json: (data) => {
          console.log(`\n🤖 Alex: ${data.reply || data.error || JSON.stringify(data)}`);
          console.log("\n-------------------------------------------------------");
          ask();
        },
        status: function (code) {
          return this;
        }
      };

      try {
        await chat(req, res);
      } catch (err) {
        console.error("❌ Error:", err.message);
        ask();
      }
    });
  }

  ask();
}
