const SavedPackage = require('../models/SavedPackage');
const Package = require('../models/Package');

exports.savePackage = async (req, res) => {
  try {
    const { packageId } = req.params;
    const { notes } = req.body;
    const userId = req.user.id;

    const pkg = await Package.findById(packageId);

    if (!pkg) {
      return res.status(404).json({
        success: false,
        message: 'Package not found'
      });
    }

    if (!pkg.isActive) {
      return res.status(400).json({
        success: false,
        message: 'Package is not available'
      });
    }

    const existingSaved = await SavedPackage.findOne({
      userId,
      packageId
    });

    if (existingSaved) {
      return res.status(400).json({
        success: false,
        message: 'Package already saved'
      });
    }

    const savedPackage = await SavedPackage.create({
      userId,
      packageId,
      notes: notes || '',
      savedAt: new Date()
    });

    res.status(201).json({
      success: true,
      message: 'Package saved successfully',
      savedPackage
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'Package already saved'
      });
    }
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Toggle save/unsave in one call
exports.toggleSavePackage = async (req, res) => {
  try {
    const { packageId } = req.params;
    const userId = req.user.id;

    const existing = await SavedPackage.findOne({ userId, packageId });

    if (existing) {
      await SavedPackage.findOneAndDelete({ userId, packageId });
      return res.json({
        success: true,
        isSaved: false,
        message: 'Package removed from saved list'
      });
    }

    const pkg = await Package.findById(packageId);
    if (!pkg) {
      return res.status(404).json({ success: false, message: 'Package not found' });
    }

    const savedPackage = await SavedPackage.create({
      userId,
      packageId,
      savedAt: new Date()
    });

    res.status(201).json({
      success: true,
      isSaved: true,
      message: 'Package saved successfully',
      savedPackage
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get count of saved packages for a user
exports.getSavedCount = async (req, res) => {
  try {
    const userId = req.user.id;
    const count = await SavedPackage.countDocuments({ userId });
    res.json({ success: true, count });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getSavedPackages = async (req, res) => {
  try {
    const userId = req.user.id;
    const { limit = 20, skip = 0 } = req.query;

    const savedPackages = await SavedPackage.find({ userId })
      .populate('packageId', 'title price location rating duration image images description')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await SavedPackage.countDocuments({ userId });

    res.json({
      success: true,
      savedPackages,
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

exports.unsavePackage = async (req, res) => {
  try {
    const { packageId } = req.params;
    const userId = req.user.id;

    const deleted = await SavedPackage.findOneAndDelete({
      userId,
      packageId
    });

    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Saved package not found'
      });
    }

    res.json({
      success: true,
      message: 'Package removed from saved list'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.checkIsSaved = async (req, res) => {
  try {
    const { packageId } = req.params;
    const userId = req.user?.id;

    if (!userId) {
      return res.json({
        success: true,
        isSaved: false
      });
    }

    const savedPackage = await SavedPackage.findOne({
      userId,
      packageId
    });

    res.json({
      success: true,
      isSaved: !!savedPackage,
      notes: savedPackage?.notes || ''
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.updateSavedNotes = async (req, res) => {
  try {
    const { packageId } = req.params;
    const { notes } = req.body;
    const userId = req.user.id;

    const savedPackage = await SavedPackage.findOne({
      userId,
      packageId
    });

    if (!savedPackage) {
      return res.status(404).json({
        success: false,
        message: 'Saved package not found'
      });
    }

    savedPackage.notes = notes || '';
    await savedPackage.save();

    res.json({
      success: true,
      message: 'Notes updated successfully',
      savedPackage
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getSavedStats = async (req, res) => {
  try {
    const userId = req.user.id;

    const savedPackages = await SavedPackage.find({ userId })
      .populate('packageId', 'price location');

    const totalSaved = savedPackages.length;
    const totalValue = savedPackages.reduce((sum, sp) => {
      return sum + (sp.packageId?.price || 0);
    }, 0);

    const locationBreakdown = {};

    savedPackages.forEach(sp => {
      const location = sp.packageId?.location || 'Other';
      locationBreakdown[location] = (locationBreakdown[location] || 0) + 1;
    });

    res.json({
      success: true,
      stats: {
        totalSaved,
        totalValue,
        averagePrice: totalSaved > 0 ? totalValue / totalSaved : 0,
        locationBreakdown
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
