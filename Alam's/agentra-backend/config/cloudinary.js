const cloudinary = require('cloudinary').v2;
const CloudinaryStorage = require('multer-storage-cloudinary');
const multer = require('multer');

cloudinary.config({
  cloud_name: 'dk66ra1nm',
  api_key: '553274952984634',
  api_secret: 'cvKaOOZznsXa9yrqiggPhcoYr7U',
});

const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    folder: 'agentra/packages',
    allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
    transformation: [{ width: 1200, height: 800, crop: 'limit' }],
  },
});

const upload = multer({ storage });

module.exports = { cloudinary, upload };