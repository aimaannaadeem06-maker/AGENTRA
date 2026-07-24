const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const authRoutes = require('./routes/auth.routes');

const app = express();

// middlewares
app.use(cors());
app.use(express.json());

// routes
app.use('/api/auth', authRoutes);

// test route
app.get('/', (req, res) => {
  res.send('API running');
});

// connect DB then init RAG
(async () => {
  await connectDB();
  try {
    const { initVectorStore } = require('./services/rag.service');
    await initVectorStore();
    console.log('✅ RAG pipeline ready');
  } catch (err) {
    console.warn('⚠️ RAG init failed:', err.message);
  }
})();

module.exports = app;
