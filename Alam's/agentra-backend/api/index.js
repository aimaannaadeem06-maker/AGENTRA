const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const { registerRoutes } = require('../src/register-routes');

const app = express();

app.use(cors());
app.use(express.json());

const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '').trim().replace(/^["']|["']$/g, '');

let cachedDb = null;

const connectDB = async () => {
    if (cachedDb && mongoose.connection.readyState === 1) {
        return cachedDb;
    }

    if (!MONGO_URI) {
        throw new Error('MONGO_URI environment variable is not defined');
    }

    try {
        const db = await mongoose.connect(MONGO_URI, {
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
            dbName: 'agentra'
        });
        cachedDb = db;
        console.log('MongoDB Connected');
        return db;
    } catch (err) {
        console.error('MongoDB Connection Failed:', err.message);
        throw err;
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

app.get('/', (req, res) => {
    res.json({
        message: 'Agentra API Server',
        version: '1.0.0',
        status: 'running',
        dbStatus: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
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
