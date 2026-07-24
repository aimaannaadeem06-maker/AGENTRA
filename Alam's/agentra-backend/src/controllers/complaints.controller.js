const Complaint = require('../models/Complaint');
const Notification = require('../models/Notification');

// ── Helpers ───────────────────────────────────────────────────────────────────
async function notifyUser(userId, title, message, type = 'GENERAL') {
  try {
    await Notification.create({ recipientId: userId, recipientType: 'USER', title, message, type });
  } catch (_) {}
}
async function notifyAgent(agentId, title, message, type = 'GENERAL') {
  try {
    await Notification.create({ recipientId: agentId, recipientType: 'AGENT', title, message, type });
  } catch (_) {}
}

// ── USER: submit complaint ────────────────────────────────────────────────────
// POST /api/complaints  (called from user frontend)
exports.submitComplaint = async (req, res) => {
  try {
    const { bookingId, subject, description } = req.body;
    const userId = req.user.id;

    if (!subject || !description) {
      return res.status(400).json({ success: false, message: 'Subject and description are required' });
    }

    // Resolve agentId from booking if provided
    let agentId = null;
    if (bookingId) {
      const Booking = require('../models/Booking');
      const booking = await Booking.findById(bookingId);
      if (booking) agentId = booking.agentId;
    }

    const complaint = await Complaint.create({
      userId,
      agentId,
      bookingId: bookingId || null,
      subject,
      description,
      status: 'OPEN'
    });

    console.log('✅ [Backend] Complaint created:', complaint._id, 'for user:', userId);
    res.status(201).json({ success: true, complaint, message: 'Complaint submitted successfully' });
  } catch (err) {
    console.error('🔴 [Backend] submitComplaint error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── USER: get my complaints ───────────────────────────────────────────────────
exports.getMyComplaints = async (req, res) => {
  try {
    const complaints = await Complaint.find({ userId: req.user.id })
      .populate('agentId', 'fullName businessName')
      .populate('bookingId', 'totalAmount travelDate')
      .sort({ createdAt: -1 });
    
    console.log(`📋 [Backend] Found ${complaints.length} complaints for user ${req.user.id}`);
    res.json({ success: true, complaints });
  } catch (err) {
    console.error('🔴 [Backend] getMyComplaints error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── owner: get all complaints ─────────────────────────────────────────────────
exports.getAllComplaints = async (req, res) => {
  try {
    const complaints = await Complaint.find()
      .populate('userId', 'fullName email')
      .populate('agentId', 'fullName email businessName')
      .populate('bookingId', 'totalAmount travelDate')
      .sort({ createdAt: -1 });
    res.json({ success: true, complaints });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── owner: forward complaint to agent ────────────────────────────────────────
// PUT /api/complaints/:id/forward
exports.forwardToAgent = async (req, res) => {
  try {
    const ownerMessage = req.body.ownerMessage || req.body.OwnerMessage || '';
    const complaint = await Complaint.findById(req.params.id)
      .populate('userId', 'fullName')
      .populate('agentId', 'fullName businessName');

    if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });
    if (!complaint.agentId) return res.status(400).json({ success: false, message: 'No agent linked to this complaint' });

    complaint.status = 'IN_PROGRESS';
    complaint.forwardedToAgent = true;
    if (ownerMessage) {
      complaint.ownerResponse = ownerMessage;
    }
    await complaint.save();

    // Notify agent
    await notifyAgent(
      complaint.agentId._id,
      '⚠️ Complaint Forwarded to You',
      `A complaint from ${complaint.userId?.fullName || 'a user'} has been forwarded to you: "${complaint.subject}". Please resolve it.`,
    );

    // Notify user that complaint is in progress
    await notifyUser(
      complaint.userId._id,
      'Complaint In Progress',
      `Your complaint "${complaint.subject}" has been forwarded to the travel agent for resolution.`,
    );

    res.json({ success: true, complaint, message: 'Complaint forwarded to agent' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── owner: resolve complaint directly ────────────────────────────────────────
// PUT /api/complaints/:id
exports.updateComplaintStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const ownerResponse = req.body.ownerResponse || req.body.OwnerResponse || '';
    const complaint = await Complaint.findById(req.params.id)
      .populate('userId', 'fullName')
      .populate('agentId', 'fullName');

    if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });

    complaint.status = status || complaint.status;
    const response = ownerResponse || '';
    if (response) {
      complaint.ownerResponse = response;
    }
    await complaint.save();

    // Notify user
    if (status === 'RESOLVED') {
      await notifyUser(
        complaint.userId._id,
        '✅ Complaint Resolved',
        `Your complaint "${complaint.subject}" has been resolved by the owner.`,
      );
    }

    res.json({ success: true, complaint, message: 'Complaint updated' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── AGENT: get complaints forwarded to me ────────────────────────────────────
exports.getAgentComplaints = async (req, res) => {
  try {
    const complaints = await Complaint.find({ agentId: req.user.id })
      .populate('userId', 'fullName email phone')
      .populate('bookingId', 'totalAmount travelDate')
      .sort({ createdAt: -1 });
    res.json({ success: true, complaints, count: complaints.length });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── AGENT: resolve complaint ──────────────────────────────────────────────────
// PUT /api/complaints/:id/resolve
exports.agentResolveComplaint = async (req, res) => {
  try {
    const { agentResponse } = req.body;
    const complaint = await Complaint.findById(req.params.id)
      .populate('userId', 'fullName');

    if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });
    if (complaint.agentId.toString() !== req.user.id.toString()) {
      return res.status(403).json({ success: false, message: 'Unauthorized' });
    }

    complaint.status = 'RESOLVED';
    complaint.agentResponse = agentResponse || 'Resolved by agent';
    await complaint.save();

    // Notify user
    await notifyUser(
      complaint.userId._id,
      '✅ Complaint Resolved',
      `Your complaint "${complaint.subject}" has been resolved by the travel agent. Response: ${agentResponse || 'Issue resolved.'}`,
    );

    res.json({ success: true, complaint, message: 'Complaint resolved successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
