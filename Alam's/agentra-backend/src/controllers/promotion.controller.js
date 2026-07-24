const Package = require('../models/Package');
const Agent = require('../models/Agent');
const Subscription = require('../models/Subscription');
const Analytics = require('../models/Analytics');

exports.promotePackage = async (req, res) => {
  try {
    const { packageId } = req.params;
    const { promotionType } = req.body;
    const agentId = req.user.id;

    const agent = await Agent.findById(agentId);
    const subscription = await Subscription.findOne({ agentId, status: 'ACTIVE' });

    if (!subscription || !subscription.aiToolsAccess.salesAgent) {
      return res.status(403).json({
        success: false,
        message: 'You need an active subscription with AI Sales Agent access to promote packages'
      });
    }

    const pkg = await Package.findOne({ _id: packageId, agentId });

    if (!pkg) {
      return res.status(404).json({
        success: false,
        message: 'Package not found or unauthorized'
      });
    }

    if (!pkg.tags) {
      pkg.tags = [];
    }

    const promotionTags = {
      featured: 'Featured',
      trending: 'Trending',
      bestseller: 'Bestseller',
      recommended: 'Recommended',
      popular: 'Popular'
    };

    if (promotionTags[promotionType]) {
      if (!pkg.tags.includes(promotionTags[promotionType])) {
        pkg.tags.push(promotionTags[promotionType]);
      }
    } else {
      pkg.tags.push('Promoted');
    }

    pkg.isActive = true;
    await pkg.save();

    let analytics = await Analytics.findOne({ packageId });
    if (!analytics) {
      analytics = await Analytics.create({
        packageId,
        agentId,
        views: 0,
        clicks: 0,
        bookings: 0
      });
    }

    res.json({
      success: true,
      message: 'Package promoted successfully',
      package: pkg,
      promotion: {
        type: promotionType || 'Standard',
        tags: pkg.tags,
        analytics: {
          views: analytics.views,
          clicks: analytics.clicks
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.stopPromotion = async (req, res) => {
  try {
    const { packageId } = req.params;
    const agentId = req.user.id;

    const pkg = await Package.findOne({ _id: packageId, agentId });

    if (!pkg) {
      return res.status(404).json({
        success: false,
        message: 'Package not found or unauthorized'
      });
    }

    pkg.tags = pkg.tags.filter(tag =>
      !['Featured', 'Trending', 'Bestseller', 'Recommended', 'Popular', 'Promoted'].includes(tag)
    );

    await pkg.save();

    res.json({
      success: true,
      message: 'Promotion stopped successfully',
      package: pkg
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPromotedPackages = async (req, res) => {
  try {
    const promotedPackages = await Package.find({
      isActive: true,
      tags: { $exists: true, $ne: [] },
      promotedAt: { $ne: null }
    })
      .populate({
        path: 'agentId',
        select: 'fullName businessName location',
        strictPopulate: false
      })
      .sort({ createdAt: -1 })
      .limit(20);

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    res.json({
      success: true,
      promotedPackages: promotedPackages.filter(pkg =>
        pkg.promotedAt &&
        new Date(pkg.promotedAt) >= sevenDaysAgo &&
        pkg.tags && pkg.tags.some(tag =>
          ['Featured', 'Trending', 'Bestseller', 'Recommended', 'Popular', 'Promoted'].includes(tag)
        )
      )
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getAgentPromotions = async (req, res) => {
  try {
    const agentId = req.user.id;

    const packages = await Package.find({
      agentId,
      tags: { $exists: true, $ne: [] }
    })
      .populate('agentId', 'fullName businessName');

    const promotedPackages = packages.filter(pkg =>
      pkg.tags && pkg.tags.some(tag =>
        ['Featured', 'Trending', 'Bestseller', 'Recommended', 'Popular', 'Promoted'].includes(tag)
      )
    );

    res.json({
      success: true,
      promotedPackages,
      total: promotedPackages.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.generatePromotionalContent = async (req, res) => {
  try {
    const { packageId } = req.params;
    const agentId = req.user.id;

    const subscription = await Subscription.findOne({ agentId, status: 'ACTIVE' });

    if (!subscription || !subscription.aiToolsAccess.salesAgent) {
      return res.status(403).json({
        success: false,
        message: 'Active subscription required for AI promotional content'
      });
    }

    const pkg = await Package.findOne({ _id: packageId, agentId });

    if (!pkg) {
      return res.status(404).json({
        success: false,
        message: 'Package not found or unauthorized'
      });
    }

    const promotionalContent = {
      title: `🌟 ${pkg.title} - Your Perfect ${pkg.location} Adventure!`,
      shortDescription: `Experience the magic of ${pkg.location} with our exclusive package. Only ${pkg.availableSeats} spots left!`,
      longDescription: `Discover ${pkg.title} - a ${pkg.duration} journey through ${pkg.location}. 

✨ Package Highlights:
- Price: $${pkg.price} per person
- Rating: ${pkg.rating}/5
- Duration: ${pkg.duration}
- Meals: ${pkg.meals}
- Transport: ${pkg.transport}
- Accommodation: ${pkg.accommodation}

Don't miss out on this incredible opportunity. Book now and create unforgettable memories in ${pkg.location}!`,

      hashtags: [
        `#${pkg.location.replace(/\s+/g, '')}`,
        '#Travel',
        '#Adventure',
        '#Vacation',
        '#Explore',
        '#Holiday'
      ],

      callToAction: [
        "Book your adventure now!",
        "Limited spots available!",
        "Don't miss out!",
        "Reserve today!"
      ],

      socialMediaPosts: [
        {
          platform: 'Instagram',
          content: `🌴 Dreaming of ${pkg.location}? ${pkg.title} is calling your name! 🌎 

${pkg.description.substring(0, 100)}...

Price: $${pkg.price} | Duration: ${pkg.duration}
Book now! #Travel #${pkg.location.replace(/\s+/g, '')}`
        },
        {
          platform: 'Facebook',
          content: `🌟 EXCLUSIVE OFFER 🌟

${pkg.title}
📍 ${pkg.location}
💰 $${pkg.price}
⏰ ${pkg.duration}

${pkg.description}

Book now: ${pkg.title}

#Travel #${pkg.location.replace(/\s+/g, '')} #Vacation`
        },
        {
          platform: 'Twitter',
          content: `✈️ ${pkg.title} in ${pkg.location} for only $${pkg.price}! ${pkg.duration} of amazing experiences. Book now: #Travel #${pkg.location.replace(/\s+/g, '')}`
        }
      ]
    };

    res.json({
      success: true,
      promotionalContent
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPromotionAnalytics = async (req, res) => {
  try {
    const { packageId } = req.params;
    const agentId = req.user.id;

    const pkg = await Package.findOne({ _id: packageId, agentId });

    if (!pkg) {
      return res.status(404).json({
        success: false,
        message: 'Package not found or unauthorized'
      });
    }

    const analytics = await Analytics.findOne({ packageId });

    if (!analytics) {
      return res.json({
        success: true,
        promotionActive: false,
        analytics: {
          views: 0,
          clicks: 0,
          bookings: 0,
          conversionRate: 0
        }
      });
    }

    const isPromoted = pkg.tags && pkg.tags.some(tag =>
      ['Featured', 'Trending', 'Bestseller', 'Recommended', 'Popular', 'Promoted'].includes(tag)
    );

    res.json({
      success: true,
      promotionActive: isPromoted,
      promotionTags: pkg.tags,
      analytics: {
        views: analytics.views,
        clicks: analytics.clicks,
        bookings: analytics.bookings,
        conversionRate: analytics.conversionRate.toFixed(2),
        revenue: analytics.revenue
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
