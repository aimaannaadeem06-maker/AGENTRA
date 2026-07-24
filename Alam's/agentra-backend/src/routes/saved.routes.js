const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const optionalAuth = require('../middleware/optional-auth.middleware');
const savedController = require('../controllers/saved.controller');

// Count must come before /:packageId to avoid route conflict
router.get('/count', protect, savedController.getSavedCount);
router.get('/stats/me', protect, savedController.getSavedStats);
router.get('/', protect, savedController.getSavedPackages);

router.post('/:packageId/toggle', protect, savedController.toggleSavePackage);
router.post('/:packageId', protect, savedController.savePackage);
router.delete('/:packageId', protect, savedController.unsavePackage);
router.get('/:packageId/check', optionalAuth, savedController.checkIsSaved);
router.put('/:packageId/notes', protect, savedController.updateSavedNotes);

module.exports = router;
