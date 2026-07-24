const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const promotionController = require('../controllers/promotion.controller');

router.get('/', promotionController.getPromotedPackages);
router.get('/agent/my', protect, role('AGENT'), promotionController.getAgentPromotions);
router.post('/promote/:packageId', protect, role('AGENT'), promotionController.promotePackage);
router.delete('/stop/:packageId', protect, role('AGENT'), promotionController.stopPromotion);
router.get('/content/:packageId', protect, role('AGENT'), promotionController.generatePromotionalContent);
router.get('/analytics/:packageId', protect, role('AGENT'), promotionController.getPromotionAnalytics);

module.exports = router;
