const Package = require('../models/Package');
const User = require('../models/User');

const isTruthyFilter = (value) => {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    return ['true', 'yes', '1', 'included'].includes(value.toLowerCase());
  }
  return false;
};

exports.searchPackages = async (req, res) => {
  try {
    const {
      q,
      location,
      cities,          // comma-separated list e.g. "Murree,Lahore"
      minPrice,
      maxPrice,
      duration,
      minRating,
      startDate,
      endDate,
      sortBy = 'createdAt',
      sortOrder = 'desc',
      limit = 20,
      skip = 0
    } = req.query;

    let query = {
      isActive: true,
      availableSeats: { $gt: 0 }
    };

    // If a search query is provided, search across all fields
    if (q) {
      query.$or = [
        { title: { $regex: q, $options: 'i' } },
        { description: { $regex: q, $options: 'i' } },
        { location: { $regex: q, $options: 'i' } },
        { tags: { $in: [new RegExp(q, 'i')] } }
      ];
    } else if (cities) {
      // Filter by specific cities (comma-separated)
      const cityList = cities.split(',').map(c => c.trim()).filter(Boolean);
      if (cityList.length > 0) {
        query.location = { $in: cityList.map(c => new RegExp(c, 'i')) };
      }
    } else if (location) {
      query.location = { $regex: location, $options: 'i' };
    }

    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = parseFloat(minPrice);
      if (maxPrice) query.price.$lte = parseFloat(maxPrice);
    }

    if (duration) {
      query.duration = { $regex: duration, $options: 'i' };
    }

    if (minRating) {
      query.rating = { $gte: parseFloat(minRating) };
    }

    if (startDate && endDate) {
      query.startDate = { $gte: new Date(startDate) };
      query.endDate = { $lte: new Date(endDate) };
    }

    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === 'asc' ? 1 : -1;

    const packages = await Package.find(query)
      .populate('agentId', 'fullName businessName location averageRating')
      .sort(sortOptions)
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await Package.countDocuments(query);

    res.json({
      success: true,
      packages,
      pagination: {
        total,
        limit: parseInt(limit),
        skip: parseInt(skip),
        hasMore: total > parseInt(skip) + parseInt(limit)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.filterPackages = async (req, res) => {
  try {
    const {
      location,
      priceRange,
      duration,
      meals,
      transport,
      accommodation,
      minRating,
      sortBy = 'rating',
      limit = 20,
      skip = 0
    } = req.body;

    let query = {
      isActive: true,
      availableSeats: { $gt: 0 }
    };

    if (location) {
      query.location = { $regex: location, $options: 'i' };
    }

    if (priceRange) {
      const [min, max] = priceRange.split('-').map(Number);
      query.price = { $gte: min, $lte: max };
    }

    if (duration) {
      query.duration = { $regex: duration, $options: 'i' };
    }

    if (meals && meals !== 'all') {
      query['includes.meals'] = isTruthyFilter(meals);
    }

    if (transport && transport !== 'all') {
      query['includes.transport'] = isTruthyFilter(transport);
    }

    if (accommodation && accommodation !== 'all') {
      query['includes.accommodation'] = isTruthyFilter(accommodation);
    }

    if (minRating) {
      query.rating = { $gte: parseFloat(minRating) };
    }

    const sortOptions = {};
    if (sortBy === 'price_low') {
      sortOptions.price = 1;
    } else if (sortBy === 'price_high') {
      sortOptions.price = -1;
    } else if (sortBy === 'rating') {
      sortOptions.rating = -1;
    } else if (sortBy === 'newest') {
      sortOptions.createdAt = -1;
    }

    const packages = await Package.find(query)
      .populate('agentId', 'fullName businessName location averageRating')
      .sort(sortOptions)
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await Package.countDocuments(query);

    res.json({
      success: true,
      packages,
      pagination: {
        total,
        limit: parseInt(limit),
        skip: parseInt(skip),
        hasMore: total > parseInt(skip) + parseInt(limit)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPopularDestinations = async (req, res) => {
  try {
    const destinations = await Package.aggregate([
      { $match: { isActive: true } },
      {
        $group: {
          _id: '$location',
          count: { $sum: 1 },
          avgRating: { $avg: '$rating' },
          avgPrice: { $avg: '$price' }
        }
      },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    res.json({
      success: true,
      destinations: destinations.map(d => ({
        location: d._id,
        packageCount: d.count,
        averageRating: d.avgRating.toFixed(1),
        averagePrice: Math.round(d.avgPrice)
      }))
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPriceRanges = async (req, res) => {
  try {
    const priceRanges = await Package.aggregate([
      { $match: { isActive: true } },
      {
        $bucket: {
          groupBy: '$price',
          boundaries: [0, 5000, 15000, 30000, 50000, 100000, Infinity],
          default: '1000+',
          output: {
            count: { $sum: 1 }
          }
        }
      }
    ]);

    res.json({
      success: true,
      priceRanges: priceRanges.map(r => ({
        label: `${r._id === 0 ? 0 : r._id - (r._id === 5000 ? 5000 : 15000)}-${r._id === '100000+' ? '100000+' : r._id}`,
        min: r._id === 0 ? 0 : r._id - (r._id === 5000 ? 5000 : 15000),
        max: r._id === '100000+' ? 100000 : r._id,
        count: r.count
      }))
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPersonalizedRecommendations = async (req, res) => {
  try {
    const userId = req.user?.id;

    if (!userId) {
      const packages = await Package.find({ isActive: true })
        .populate('agentId', 'fullName businessName')
        .sort({ rating: -1 })
        .limit(10);

      return res.json({
        success: true,
        type: 'general',
        recommendations: packages
      });
    }

    const user = await User.findById(userId).select('preferences');

    let query = { isActive: true };

    if (user.preferences?.budget) {
      query.price = {};
      if (user.preferences.budget.min) query.price.$gte = user.preferences.budget.min;
      if (user.preferences.budget.max) query.price.$lte = user.preferences.budget.max;
    }

    if (user.preferences?.preferredLocations?.length > 0) {
      query.location = {
        $in: user.preferences.preferredLocations.map(loc => new RegExp(loc, 'i'))
      };
    }

    const packages = await Package.find(query)
      .populate('agentId', 'fullName businessName')
      .sort({ rating: -1 })
      .limit(10);

    res.json({
      success: true,
      type: 'personalized',
      recommendations: packages
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getSimilarPackages = async (req, res) => {
  try {
    const { packageId } = req.params;

    const referencePackage = await Package.findById(packageId);

    if (!referencePackage) {
      return res.status(404).json({
        success: false,
        message: 'Package not found'
      });
    }

    const similarPackages = await Package.find({
      _id: { $ne: packageId },
      isActive: true,
      $or: [
        { location: referencePackage.location },
        { price: { $gte: referencePackage.price * 0.8, $lte: referencePackage.price * 1.2 } },
        { duration: referencePackage.duration }
      ]
    })
      .populate('agentId', 'fullName businessName')
      .limit(5);

    res.json({
      success: true,
      referencePackage,
      similarPackages
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
