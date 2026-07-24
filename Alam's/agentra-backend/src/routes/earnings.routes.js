const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const earningsController = require('../controllers/earnings.controller');

router.get('/overview', protect, role('AGENT'), earningsController.getEarningsOverview);
router.get('/commission', protect, role('AGENT'), earningsController.getCommissionBreakdown);
router.get('/by-package', protect, role('AGENT'), earningsController.getEarningsByPackage);
router.get('/payouts', protect, role('AGENT'), earningsController.getPayoutHistory);
router.post('/request-payout', protect, role('AGENT'), earningsController.requestPayout);
router.get('/report', protect, role('AGENT'), earningsController.getEarningsReport);

module.exports = router;
