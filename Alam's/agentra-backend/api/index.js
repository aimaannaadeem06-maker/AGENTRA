const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const { registerRoutes } = require('../src/register-routes');

const app = express();

app.use(cors({
    origin: function (origin, callback) {
        callback(null, true);
    },
    credentials: true,
}));
app.use(express.json());

const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '').trim().replace(/^["']|["']$/g, '');
const MONGO_URI_FALLBACK = 'mongodb://n8nuser:n8npass123@ac-80xwjau-shard-00-00.7b3wkfw.mongodb.net:27017,ac-80xwjau-shard-00-01.7b3wkfw.mongodb.net:27017,ac-80xwjau-shard-00-02.7b3wkfw.mongodb.net:27017/agentra?ssl=true&replicaSet=atlas-gf3dvo-shard-0&authSource=admin&appName=Cluster0';

let cachedDb = null;

const connectDB = async () => {
    if (cachedDb && mongoose.connection.readyState === 1) {
        return cachedDb;
    }

    try {
        const uri = MONGO_URI || MONGO_URI_FALLBACK;
        const db = await mongoose.connect(uri, {
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
            dbName: 'agentra'
        });
        cachedDb = db;
        console.log('MongoDB Connected');
        return db;
    } catch (err) {
        console.error('MongoDB Connection Failed:', err.message);
        try {
            const fallbackDb = await mongoose.connect(MONGO_URI_FALLBACK, {
                serverSelectionTimeoutMS: 5000,
                socketTimeoutMS: 45000,
                dbName: 'agentra'
            });
            cachedDb = fallbackDb;
            console.log('MongoDB Connected via fallback URI');
            return fallbackDb;
        } catch (fallbackErr) {
            console.error('MongoDB Fallback Connection Failed:', fallbackErr.message);
            throw fallbackErr;
        }
    }
};

// Middleware to ensure DB connection
app.use(async (req, res, next) => {
    try {
        await connectDB();
        next();
    } catch (err) {
        res.status(500).json({
            success: false,
            message: 'Database connection failed',
            error: err.message
        });
    }
});

// Middleware to pre-warm RAG service on serverless request
let ragInitialized = false;
app.use(async (req, res, next) => {
    if (!ragInitialized) {
        try {
            const { initVectorStore } = require('../src/services/rag.service');
            await initVectorStore();
            ragInitialized = true;
        } catch (err) {
            console.error('RAG init warning on Vercel:', err.message);
        }
    }
    next();
});

// Root & Health Check routes
app.get(['/', '/health', '/api/health'], (req, res) => {
    res.json({
        success: true,
        status: 'healthy',
        message: 'Agentra API Server',
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'production',
        mongodb: mongoose.connection.readyState === 1 ? '✅ Connected' : '❌ Disconnected'
    });
});

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

// Import and use routes
try {
    registerRoutes(app);
} catch (err) {
    console.error('Error loading routes:', err);
}

app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Route not found'
    });
});

app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Internal Server Error'
    });
});

module.exports = app;
