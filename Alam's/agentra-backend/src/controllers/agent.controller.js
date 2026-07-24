const Package = require('../models/Package');
const Agent = require('../models/Agent');

// ---------------- CREATE PACKAGE ----------------
exports.createPackage = async (req, res) => {
  try {
    const agent = await Agent.findById(req.user.id);
    if (!agent)
      return res.status(404).json({ message: "Agent not found" });

    // Check if agent is approved by owner
    if (agent.status !== 'APPROVED')
      return res.status(403).json({ message: "Your account must be approved by owner to create packages" });

    // Check if agent is verified (email verified)
    if (!agent.isVerified)
      return res.status(403).json({ message: "Agent email must be verified" });

    const {
      title,
      description,
      price,
      duration,
      location,
      meals,
      transport,
      accommodation,
      availableSeats,
      startDate,
      endDate
    } = req.body;

    const newPackage = await Package.create({
      agentId: req.user.id,
      title,
      description,
      price,
      duration,
      location,
      meals,
      transport,
      accommodation,
      availableSeats,
      startDate,
      endDate
    });

    await Agent.findByIdAndUpdate(req.user.id, { $inc: { totalPackages: 1 } });

    res.status(201).json({
      success: true,
      message: 'Package created successfully',
      package: newPackage
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------------- UPDATE PACKAGE ----------------
exports.updatePackage = async (req, res) => {
  try {
    const updated = await Package.findOneAndUpdate(
      { _id: req.params.id, agentId: req.user.id },
      req.body,
      { new: true }
    );

    if (!updated)
      return res.status(404).json({ message: 'Package not found or unauthorized' });

    res.json({ success: true, message: 'Package updated successfully', package: updated });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------------- DELETE PACKAGE ----------------
exports.deletePackage = async (req, res) => {
  try {
    const deleted = await Package.findOneAndDelete({
      _id: req.params.id,
      agentId: req.user.id
    });

    if (!deleted)
      return res.status(404).json({ message: 'Package not found or unauthorized' });

    await Agent.findByIdAndUpdate(req.user.id, { $inc: { totalPackages: -1 } });

    res.json({ success: true, message: 'Package deleted successfully' });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------------- GET AGENT PACKAGES ----------------
exports.getAgentPackages = async (req, res) => {
  try {
    const packages = await Package.find({ agentId: req.user.id })
      .sort({ createdAt: -1 });

    res.json({ success: true, total: packages.length, packages });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
