const express = require('express');
const mongoose = require('mongoose');
const dns = require('dns');
const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');
const cors = require('cors');
const { registerRoutes } = require('./src/register-routes');

dotenv.config();

const PORT = process.env.PORT || 5000;

const app = express();

// Middleware: create upload folders and expose them to clients
const UPLOADS_BASE = path.join(__dirname, 'uploads');
const PROFILE_UPLOADS = path.join(UPLOADS_BASE, 'profiles');
const PACKAGE_UPLOADS = path.join(UPLOADS_BASE, 'packages');
[UPLOADS_BASE, PROFILE_UPLOADS, PACKAGE_UPLOADS].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Middlewares
app.use(cors({
  origin: function (origin, callback) {
    callback(null, true);
  },
  credentials: true,
}));
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


app.use((req, res, next) => {
  console.log("🔥 REQUEST HIT:");
  console.log("METHOD:", req.method);
  console.log("URL:", req.originalUrl);
  console.log("PATH:", req.path);
  console.log("BODY:", req.body);
  console.log("-----------------------------");
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// DB URI — try SRV first, fall back to non-SRV if needed
const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '')
  .trim()
  .replace(/^["']|["']$/g, '');

// Non-SRV fallback (works even when DNS SRV is blocked)
const MONGO_URI_FALLBACK = 'mongodb://n8nuser:n8npass123@ac-80xwjau-shard-00-00.7b3wkfw.mongodb.net:27017,ac-80xwjau-shard-00-01.7b3wkfw.mongodb.net:27017,ac-80xwjau-shard-00-02.7b3wkfw.mongodb.net:27017/agentra?ssl=true&replicaSet=atlas-gf3dvo-shard-0&authSource=admin&appName=Cluster0';

if (!MONGO_URI) {
  console.error('❌ MONGO_URI missing in .env');
}
// Always use Google DNS for Atlas SRV resolution on Render
dns.setServers(['8.8.8.8', '1.1.1.1']);
console.log('🌐 Using public DNS for Atlas SRV resolution');

// DB Connection
const connectDB = async () => {
  const connect = async (uri) => {
    await mongoose.connect(uri, {
      dbName: 'agentra',
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
      connectTimeoutMS: 10000,
      retryWrites: true,
    });
  };

  try {
    if (mongoose.connection.readyState >= 1) {
      return;
    }

    console.log('🔄 Connecting to MongoDB...');
    console.log('📍 URI:', MONGO_URI.substring(0, 30) + '...');

    await connect(MONGO_URI);
    console.log('✅ MongoDB Connected Successfully');
    return true;
  } catch (err) {
    console.error('❌ MongoDB SRV Connection Failed:', err.message);
    console.log('🔁 Retrying with non-SRV direct connection string...');

    try {
      await connect(MONGO_URI_FALLBACK);
      console.log('✅ MongoDB Connected via direct URI fallback');
      return true;
    } catch (fallbackErr) {
      console.error('❌ MongoDB fallback also failed:', fallbackErr.message);
    }

    console.error('⚠️  Stack:', err.stack);
    return false;
  }
};

// Initial connection attempt — don't exit on failure, keep retrying per-request
(async () => {
  const connected = await connectDB();
  if (!connected) {
    console.warn('⚠️  MongoDB not connected at startup — will retry on each request');
  }
})();

// Ensure DB connection before processing requests
app.use(async (req, res, next) => {
  if (mongoose.connection.readyState !== 1) {
    console.log('⚠️  MongoDB disconnected. Attempting reconnection...');
    await connectDB();
  }
  next();
});

// Root route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Agentra API Running',
  });
});

// Health check route (no auth required)
app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    mongodb: mongoose.connection.readyState === 1 ? '✅ Connected' : '❌ Disconnected',
    port: PORT,
    environment: process.env.NODE_ENV
  });
});

// Status check route
app.get('/api/status', (req, res) => {
  res.json({
    success: true,
    api: 'Agentra Travel Management System',
    version: '1.0.0',
    status: 'running',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// ================= ROUTES =================
registerRoutes(app);

// Pre-warm the RAG keyword index after DB connects (non-blocking)
// This runs once so the first chat request is instant.
(async () => {
  try {
    const { initVectorStore } = require('./src/services/rag.service');
    await initVectorStore();
  } catch (err) {
    console.warn('⚠️  RAG index warm-up failed (non-fatal):', err.message);
  }
})();

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({
    success: false,
    message: err.message || 'Server Error',
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on ${PORT}`);
});

module.exports = app;
