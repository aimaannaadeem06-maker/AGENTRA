const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const optionalAuth = require('../middleware/optional-auth.middleware');
const role = require('../middleware/role.middleware');
const userController = require('../controllers/user.controller');
const { profileUpload } = require('../config/multer');

// ================= PROFILE =================
router.get('/profile', protect, role('USER'), userController.getProfile);
router.put('/profile', protect, role('USER'), userController.updateProfile);
router.post('/upload-profile', protect, role('USER'), profileUpload.single('image'), userController.uploadProfileImage);

// ================= BOOKINGS =================
router.post('/bookings', protect, role('USER'), userController.createBooking);
router.get('/bookings', protect, role('USER'), userController.getUserBookings);

// ================= REVIEWS =================
router.post('/reviews', protect, role('USER'), userController.createReview);
router.get('/reviews', optionalAuth, userController.getUserReviews);

// ================= COMPLAINTS =================
router.post('/complaints', protect, role('USER'), userController.raiseComplaint);
router.get('/complaints', protect, role('USER'), userController.getUserComplaints);

// ================= AI PREFERENCES =================
router.put('/preferences', protect, role('USER'), userController.updatePreferences);

// ================= FAVORITES =================
router.post('/favorites/toggle', protect, role('USER'), userController.toggleFavorite);
router.get('/favorites', protect, role('USER'), userController.getFavorites);

// ================= ACCOUNT =================
router.patch('/deactivate', protect, role('USER'), userController.deactivateAccount);

module.exports = router;
