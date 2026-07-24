const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const uploadDir = process.env.VERCEL || process.env.NODE_ENV === 'production' 
  ? '/tmp/uploads' 
  : path.join(__dirname, '..', '..', 'uploads');
const profileDir = path.join(uploadDir, 'profiles');
const packageDir = path.join(uploadDir, 'packages');

const ensureDirectoryExists = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`[Multer] Created directory: ${dir}`);
  } else {
    console.log(`[Multer] Directory exists: ${dir}`);
  }
};

console.log('[Multer] Upload directories:');
console.log(`  uploadDir: ${uploadDir}`);
console.log(`  profileDir: ${profileDir}`);
console.log(`  packageDir: ${packageDir}`);

ensureDirectoryExists(uploadDir);
ensureDirectoryExists(profileDir);
ensureDirectoryExists(packageDir);

const allowedMimeTypes = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];

const sanitizeFileName = (originalName) => {
  const ext = path.extname(originalName).toLowerCase();
  const baseName = path.basename(originalName, ext)
    .replace(/\s+/g, '-')
    .replace(/[^a-zA-Z0-9_-]/g, '')
    .toLowerCase();

  const uniqueSuffix = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}`;
  return `${baseName || 'upload'}-${uniqueSuffix}${ext || '.jpg'}`;
};

const isAllowedExtension = (originalName) => {
  const ext = path.extname(originalName).toLowerCase();
  return ['.jpg', '.jpeg', '.png', '.webp'].includes(ext);
};

const createStorage = (destination) => multer.diskStorage({
  destination: (req, file, cb) => {
    console.log(`[Multer] Destination selected for ${file.originalname}: ${destination}`);
    cb(null, destination);
  },
  filename: (req, file, cb) => {
    const filename = sanitizeFileName(file.originalname);
    console.log(`[Multer] Generated filename for ${file.originalname}: ${filename}`);
    cb(null, filename);
  },
});

const fileFilter = (req, file, cb) => {
  const hasValidMimeType = allowedMimeTypes.includes(file.mimetype);
  const hasValidExtension = isAllowedExtension(file.originalname);

  if (!hasValidMimeType && !hasValidExtension) {
    console.log(
      `[Multer] Rejected ${file.originalname}: mime type ${file.mimetype}, extension ${path.extname(file.originalname)}`
    );
    return cb(new Error('Unsupported file type. Only JPG, JPEG, PNG and WEBP are allowed.'), false);
  }

  if (!hasValidMimeType && hasValidExtension) {
    console.log(
      `[Multer] Accepted ${file.originalname} by extension fallback: mime type ${file.mimetype}, extension ${path.extname(file.originalname)}`
    );
  } else {
    console.log(`[Multer] Accepted ${file.originalname}: mime type ${file.mimetype}`);
  }

  cb(null, true);
};

const profileUpload = multer({
  storage: createStorage(profileDir),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter,
});

const packageUpload = multer({
  storage: createStorage(packageDir),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter,
});

const generalUpload = multer({
  storage: createStorage(uploadDir),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter,
});

module.exports = {
  profileUpload,
  packageUpload,
  generalUpload,
};
