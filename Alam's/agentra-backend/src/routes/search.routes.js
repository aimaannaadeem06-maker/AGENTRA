const express = require('express');
const router = express.Router();

const searchController = require('../controllers/search.controller');

router.get('/', searchController.searchPackages);
router.post('/filter', searchController.filterPackages);
router.get('/popular-destinations', searchController.getPopularDestinations);
router.get('/price-ranges', searchController.getPriceRanges);
router.get('/recommendations', searchController.getPersonalizedRecommendations);
router.get('/similar/:packageId', searchController.getSimilarPackages);

module.exports = router;
