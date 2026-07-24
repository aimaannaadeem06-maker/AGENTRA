const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const refundController = require('../controllers/refund.controller');

router.post('/request', protect, role('USER'), refundController.requestRefund);
router.get('/my', protect, role('USER'), refundController.getMyRefundRequests);
router.get('/agent', protect, role('AGENT'), refundController.getRefundRequests);
router.post('/approve/:bookingId', protect, role('AGENT'), refundController.approveRefund);
router.post('/reject/:bookingId', protect, role('AGENT'), refundController.rejectRefund);
router.get('/stats', protect, role('AGENT'), refundController.getRefundStats);
router.get('/all', protect, role('OWNER'), refundController.getAllRefundRequests);

module.exports = router;
