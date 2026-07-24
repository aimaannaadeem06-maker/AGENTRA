const Package = require('../models/Package');
const Agent = require('../models/Agent');

// ================= PUBLIC =================

/**
 * Normalise a package document so that `image` is always populated.
 * If `image` is empty but `images[]` has entries, use the first entry.
 * This ensures the user-facing app always has a displayable photo (Bug 7).
 */
function normaliseImage(pkg) {
  const obj = pkg.toObject ? pkg.toObject() : pkg;
  if (!obj.image && obj.images && obj.images.length > 0) {
    obj.image = obj.images[0];
  }
  return obj;
}

exports.getPublicPackages = async (req, res) => {
  try {
    const packages = await Package.find({ isActive: true })
      .populate('agentId', 'fullName businessName cancellationPolicy');
    res.json({ success: true, packages: packages.map(normaliseImage) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getLocations = async (req, res) => {
  try {
    const locations = await Package.distinct('location', { isActive: true });
    res.json({ success: true, locations });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPackageDetails = async (req, res) => {
  try {
    const pkg = await Package.findById(req.params.id)
      .populate('agentId', 'fullName businessName cancellationPolicy');

    if (!pkg || !pkg.isActive)
      return res.status(404).json({ success: false, message: 'Package not available' });

    res.json({ success: true, package: normaliseImage(pkg) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= AGENT =================
exports.createPackage = async (req, res) => {
  try {
    const pkg = await Package.create({ ...req.body, agentId: req.user.id });
    await Agent.findByIdAndUpdate(req.user.id, { $inc: { totalPackages: 1 } });

    res.status(201).json({ success: true, package: normaliseImage(pkg) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.uploadPackageImage = async (req, res) => {
  try {
    const { packageId } = req.body;
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }
    if (!packageId) {
      return res.status(400).json({ success: false, message: 'packageId is required' });
    }

    const pkg = await Package.findOne({ _id: packageId, agentId: req.user.id });
    if (!pkg) {
      return res.status(404).json({ success: false, message: 'Package not found or unauthorized' });
    }

    const imagePath = `/uploads/packages/${req.file.filename}`;
    console.log('📤 Package image saved:', imagePath, 'for package:', packageId, 'agent:', req.user.id);
    pkg.image = imagePath;
    pkg.images = Array.isArray(pkg.images) ? pkg.images : [];
    if (!pkg.images.includes(imagePath)) {
      pkg.images.unshift(imagePath);
    }
    await pkg.save();

    res.json({ success: true, url: imagePath, package: normaliseImage(pkg) });
  } catch (err) {
    console.error('🔴 Upload package image error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getAgentPackages = async (req, res) => {
  try {
    const packages = await Package.find({ agentId: req.user.id });
    res.json({ success: true, packages: packages.map(normaliseImage) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.updatePackage = async (req, res) => {
  try {
    const updated = await Package.findOneAndUpdate(
      { _id: req.params.id, agentId: req.user.id },
      req.body,
      { new: true }
    );

    if (!updated)
      return res.status(404).json({ success: false, message: 'Not found or unauthorized' });

    res.json({ success: true, package: normaliseImage(updated) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.deletePackage = async (req, res) => {
  try {
    const deleted = await Package.findOneAndDelete({ _id: req.params.id, agentId: req.user.id });

    if (!deleted)
      return res.status(404).json({ success: false, message: 'Not found or unauthorized' });

    await Agent.findByIdAndUpdate(req.user.id, { $inc: { totalPackages: -1 } });

    res.json({ success: true, message: 'Package deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= OWNER =================
exports.getAllPackages = async (req, res) => {
  try {
    const packages = await Package.find();
    res.json({ success: true, packages: packages.map(normaliseImage) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.togglePackageStatus = async (req, res) => {
  try {
    const pkg = await Package.findById(req.params.id);

    if (!pkg)
      return res.status(404).json({ success: false, message: 'Package not found' });

    pkg.isActive = !pkg.isActive;
    await pkg.save();

    res.json({ success: true, status: pkg.isActive });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.cleanupPackages = async (req, res) => {
  try {
    const packages = await Package.find({ title: { $regex: 'Dream Vacation', $options: 'i' } });

    // Safety check: ensure we found some packages
    if (packages.length === 0) {
      return res.json({ success: true, message: 'No matching packages found to delete.' });
    }

    // Delete the first 2 found packages
    const toDelete = packages.slice(0, 2);

    for (const pkg of toDelete) {
      await Package.findByIdAndDelete(pkg._id);
    }

    res.json({
      success: true,
      message: `Successfully deleted ${toDelete.length} packages.`,
      deletedPackages: toDelete.map(p => p.title)
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
