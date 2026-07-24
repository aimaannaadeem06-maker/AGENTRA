const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const subscriptionController = require('../controllers/subscription.controller');

router.get('/plans', subscriptionController.getSubscriptionPlans);
router.post('/subscribe', protect, role('AGENT'), subscriptionController.subscribe);
router.get('/current', protect, role('AGENT'), subscriptionController.getCurrentSubscription);
router.post('/cancel', protect, role('AGENT'), subscriptionController.cancelSubscription);
router.post('/upgrade', protect, role('AGENT'), subscriptionController.upgradeSubscription);
router.get('/check-access', protect, role('AGENT'), subscriptionController.checkSubscriptionAccess);

module.exports = router;
