const Agent = require('../models/Agent');
const Complaint = require('../models/Complaint');
const Booking = require('../models/Booking');
const User = require('../models/User');

// ---------- GET ALL AGENTS ----------
exports.getAgents = async (req, res) => {
  try {
    const agents = await Agent.find().select('-password').sort({ createdAt: -1 });
    res.json({ success: true, agents });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- VERIFY AGENT ----------
exports.verifyAgent = async (req, res) => {
  try {
    await Agent.findByIdAndUpdate(req.params.id, {
      status: 'APPROVED',
      isVerified: true,
      emailVerified: true
    });
    res.json({ success: true, message: 'Agent verified successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- SEND NOTICE ----------
// Sends a 30-day warning notice to the agent before blocking or deleting.
// Stores noticeSentAt, noticeType, noticeMessage on the agent document
// AND creates an in-app notification so the bell icon shows it immediately.
exports.sendNotice = async (req, res) => {
  try {
    const { noticeType, noticeMessage } = req.body;

    if (!noticeType || !['block', 'delete'].includes(noticeType)) {
      return res.status(400).json({
        success: false,
        message: 'noticeType must be "block" or "delete"'
      });
    }

    const agent = await Agent.findById(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    const defaultMessage = noticeType === 'block'
      ? `Your account has been flagged for blocking. If the issue is not resolved within 30 days, your account will be blocked and you will no longer be able to log in.`
      : `Your account has been flagged for deletion. If the issue is not resolved within 30 days, your account will be permanently deleted from the platform.`;

    const finalMessage = noticeMessage || defaultMessage;

    await Agent.findByIdAndUpdate(req.params.id, {
      noticeSentAt: new Date(),
      noticeType,
      noticeMessage: finalMessage
    });

    // Create in-app notification so the agent's bell icon shows it
    const Notification = require('../models/Notification');
    await Notification.create({
      recipientId: agent._id,
      recipientType: 'AGENT',
      title: noticeType === 'block' ? '⚠️ Account Block Warning' : '⚠️ Account Deletion Warning',
      message: finalMessage,
      type: 'GENERAL'
    });

    res.json({
      success: true,
      message: `30-day ${noticeType} notice sent to ${agent.fullName}`,
      noticeSentAt: new Date(),
      noticeType
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- BLOCK AGENT ----------
exports.blockAgent = async (req, res) => {
  try {
    const agent = await Agent.findById(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    await Agent.findByIdAndUpdate(req.params.id, {
      status: 'BLOCKED',
      isVerified: false,
      noticeSentAt: null,
      noticeType: null,
      noticeMessage: ''
    });

    // Create in-app notification for the agent
    const Notification = require('../models/Notification');
    await Notification.create({
      recipientId: agent._id,
      recipientType: 'AGENT',
      title: 'Account Blocked',
      message: 'Your account has been blocked by the owner. You will not be able to log in until the issue is resolved. Please contact support for more information.',
      type: 'ACCOUNT_BLOCKED'
    });

    res.json({ success: true, message: `${agent.fullName}'s account has been blocked` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- UNBLOCK AGENT ----------
exports.unblockAgent = async (req, res) => {
  try {
    const agent = await Agent.findById(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    await Agent.findByIdAndUpdate(req.params.id, {
      status: 'APPROVED',
      isVerified: true,
      noticeSentAt: null,
      noticeType: null,
      noticeMessage: ''
    });

    res.json({ success: true, message: `${agent.fullName}'s account has been unblocked` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- DELETE AGENT ----------
exports.deleteAgent = async (req, res) => {
  try {
    const agent = await Agent.findById(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    // Create notification before deleting (so we have the agent data)
    const Notification = require('../models/Notification');
    await Notification.create({
      recipientId: agent._id,
      recipientType: 'AGENT',
      title: 'Account Deleted',
      message: 'Your account has been permanently deleted by the owner. All your data has been removed from the platform. Please contact support if you believe this was a mistake.',
      type: 'ACCOUNT_DELETED'
    });

    await Agent.findByIdAndDelete(req.params.id);

    res.json({
      success: true,
      message: `${agent.fullName}'s account has been permanently deleted`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- REJECT AGENT (legacy — kept for backward compat) ----------
exports.rejectAgent = async (req, res) => {
  try {
    const agent = await Agent.findById(req.params.id);
    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }
    await Agent.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Agent application rejected and removed' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- GET COMPLAINTS ----------
exports.getComplaints = async (req, res) => {
  try {
    const complaints = await Complaint.find()
      .populate('userId')
      .populate('bookingId')
      .sort({ createdAt: -1 });
    res.json({ success: true, complaints });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- RESPOND COMPLAINT ----------
exports.respondComplaint = async (req, res) => {
  try {
    const { response, status } = req.body;
    await Complaint.findByIdAndUpdate(req.params.id, {
      ownerResponse: response,
      status
    });
    res.json({ success: true, message: 'Complaint updated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ---------- DASHBOARD STATS ----------
exports.getDashboardStats = async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalAgents = await Agent.countDocuments();
    const totalBookings = await Booking.countDocuments();
    const totalComplaints = await Complaint.countDocuments();
    
    // Revenue calculations
    const Transaction = require('../models/Transaction');
    const revenueData = await Transaction.aggregate([
      {
        $match: {
          type: { $in: ['COMMISSION', 'SUBSCRIPTION'] }
        }
      },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$amount' }
        }
      }
    ]);

    const totalRevenue = revenueData.length > 0 ? revenueData[0].totalRevenue : 0;

    res.json({
      success: true,
      stats: { totalUsers, totalAgents, totalBookings, totalComplaints, totalRevenue }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
