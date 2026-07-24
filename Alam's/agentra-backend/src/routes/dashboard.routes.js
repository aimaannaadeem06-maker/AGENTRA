const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const dashboardController = require('../controllers/dashboard.controller');

// ========== USER DASHBOARD ==========
router.get('/user', protect, role('USER'), dashboardController.userDashboard);

// ========== AGENT DASHBOARD ==========
router.get('/agent', protect, role('AGENT'), dashboardController.agentDashboard);

// ========== OWNER DASHBOARD ==========
router.get('/owner', protect, role('OWNER'), dashboardController.ownerDashboard);
router.get('/owner/commission-analytics', protect, role('OWNER'), dashboardController.getOwnerCommissionAnalytics);
router.get('/owner/commission-report', protect, role('OWNER'), dashboardController.exportOwnerCommissionReport);

module.exports = router;
