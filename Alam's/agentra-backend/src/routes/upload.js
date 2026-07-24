const path = require('path');
const fs = require('fs');
const express = require('express');
const router = express.Router();
const { generalUpload } = require('../config/multer');

router.post('/image', generalUpload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    let finalUrl = `/uploads/${req.file.filename}`;

    // 1. Try uploading to Cloudinary
    try {
      const cloudinary = require('cloudinary').v2;
      cloudinary.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'dk66ra1nm',
        api_key: process.env.CLOUDINARY_API_KEY || '553274952984634',
        api_secret: process.env.CLOUDINARY_API_SECRET || 'cvKaOOZznsXa9yrqiggPhcoYr7U',
      });
      const filePath = req.file.path;
      if (filePath && fs.existsSync(filePath)) {
        const result = await cloudinary.uploader.upload(filePath, {
          folder: 'agentra/uploads',
        });
        if (result && result.secure_url) {
          finalUrl = result.secure_url;
        }
      }
    } catch (cErr) {
      console.warn('⚠️ Cloudinary upload failed, falling back to base64 data URI:', cErr.message);
      // 2. Fallback: Convert to Base64 Data URI so it works everywhere without static file storage
      if (req.file.buffer) {
        const mimeType = req.file.mimetype || 'image/jpeg';
        finalUrl = `data:${mimeType};base64,${req.file.buffer.toString('base64')}`;
      } else if (req.file.path && fs.existsSync(req.file.path)) {
        const fileData = fs.readFileSync(req.file.path);
        const mimeType = req.file.mimetype || 'image/jpeg';
        finalUrl = `data:${mimeType};base64,${fileData.toString('base64')}`;
      }
    }

    res.json({
      success: true,
      url: finalUrl,
      path: finalUrl,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
