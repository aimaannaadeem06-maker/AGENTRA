const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const analyticsController = require('../controllers/analytics.controller');

router.get('/dashboard', protect, role('AGENT'), analyticsController.getDashboardStats);
router.get('/agent', protect, role('AGENT'), analyticsController.getAgentAnalytics);
router.get('/package/:id', protect, role('AGENT'), analyticsController.getPackageAnalytics);
router.post('/package/:id/view', analyticsController.trackPackageView);
router.post('/package/:id/click', analyticsController.trackPackageClick);
router.get('/package/:id/report', protect, role('AGENT'), analyticsController.generatePDFReport);

module.exports = router;
