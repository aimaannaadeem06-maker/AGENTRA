const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const Agent = require('../models/Agent');
const Complaint = require('../models/Complaint');
const Booking = require('../models/Booking');

router.get('/me', protect, (req, res) => {
  res.json({ success: true, user: req.user });
});

// Compatibility: some clients call /api/agents for owner listing.
router.get('/', protect, role('OWNER'), async (req, res) => {
  try {
    const agents = await Agent.find().select('-password');
    res.json({ success: true, agents });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ========== AGENT: GET COMPLAINTS ABOUT THEIR PACKAGES ==========
router.get('/complaints', protect, role('AGENT'), async (req, res) => {
  try {
    const complaints = await Complaint.find({ agentId: req.user.id })
      .populate('userId', 'fullName email')
      .populate('bookingId')
      .sort({ createdAt: -1 });
    res.json({ success: true, complaints });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ========== AGENT: GET BOOKINGS ON THEIR PACKAGES ==========
router.get('/bookings', protect, role('AGENT'), async (req, res) => {
  try {
    const bookings = await Booking.find({ agentId: req.user.id })
      .populate('userId', 'fullName email phone')
      .populate('packageId', 'title location price image')
      .sort({ createdAt: -1 });
    res.json({ success: true, bookings });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
