const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const paymentController = require('../controllers/payment.controller');

router.get('/methods', paymentController.getPaymentMethods);
router.post('/intent', protect, paymentController.createPaymentIntent);
router.post('/process', protect, paymentController.processPayment);
router.get('/verify/:transactionId', protect, paymentController.verifyPayment);
router.post('/refund', protect, paymentController.processRefund);
router.get('/history', protect, paymentController.getTransactionHistory);

// ========== OWNER: ALL TRANSACTIONS ==========
router.get('/all', protect, role('OWNER'), async (req, res) => {
  try {
    const Transaction = require('../models/Transaction');
    const { limit = 100, skip = 0 } = req.query;
    const transactions = await Transaction.find()
      .populate('userId', 'fullName email')
      .populate('agentId', 'fullName businessName')
      .populate('packageId', 'title location')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));
    res.json({ success: true, transactions });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
