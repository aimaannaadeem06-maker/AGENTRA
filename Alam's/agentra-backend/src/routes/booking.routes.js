const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const bookingController = require('../controllers/booking.controller');

// ========== USER ==========
router.post('/', protect, role('USER'), bookingController.createBooking);
router.get('/my', protect, role('USER'), bookingController.getUserBookings);
router.put('/:id/cancel', protect, role('USER', 'AGENT', 'OWNER', 'ADMIN'), bookingController.cancelBooking);

// ========== AGENT ==========
router.get('/agent', protect, role('AGENT'), bookingController.getAgentBookings);

// ========== OWNER ==========
router.get('/all', protect, role('OWNER'), bookingController.getAllBookings);

module.exports = router;
