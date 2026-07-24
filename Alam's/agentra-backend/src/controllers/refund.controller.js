const Booking = require('../models/Booking');
const Complaint = require('../models/Complaint');
const Package = require('../models/Package');
const Transaction = require('../models/Transaction');
const User = require('../models/User');
const Agent = require('../models/Agent');
const mongoose = require('mongoose');

exports.requestRefund = async (req, res) => {
  try {
    const { bookingId, reason } = req.body;
    const userId = req.user.id;

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    if (booking.userId.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    if (booking.paymentStatus !== 'PAID') {
      return res.status(400).json({
        success: false,
        message: 'Cannot refund unpaid booking'
      });
    }

    if (booking.refundStatus !== 'NONE') {
      return res.status(400).json({
        success: false,
        message: 'Refund already requested or processed'
      });
    }

    booking.status = 'CANCELLED';
    booking.refundStatus = 'REQUESTED';
    booking.cancellationReason = reason;
    await booking.save();

    await Complaint.create({
      userId,
      agentId: booking.agentId,
      bookingId: booking._id,
      subject: 'Refund Request',
      description: `Refund request for booking: ${reason}`,
      status: 'OPEN'
    });

    res.json({
      success: true,
      message: 'Refund request submitted successfully',
      booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getRefundRequests = async (req, res) => {
  try {
    const agentId = req.user.id;
    const { status } = req.query;

    // Return ALL refund requests for this agent (not just REQUESTED)
    // so the frontend can show them in Pending/Accepted/Rejected tabs
    let query = { agentId, refundStatus: { $ne: 'NONE' } };
    if (status) {
      query = { agentId, refundStatus: status };
    }

    const bookings = await Booking.find(query)
      .populate('userId', 'fullName email phone')
      .populate('packageId', 'title location price')
      .populate('agentId', 'fullName businessName')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      refundRequests: bookings,
      total: bookings.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.approveRefund = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { reason } = req.body;
    const agentId = req.user.id;

    const booking = await Booking.findById(bookingId)
      .populate('packageId')
      .populate('agentId');

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    if (booking.agentId._id.toString() !== agentId.toString()) {
      return res.status(403).json({ success: false, message: 'Unauthorized' });
    }

    if (booking.refundStatus !== 'REQUESTED') {
      return res.status(400).json({ success: false, message: 'Refund not requested' });
    }

    const refundAmount = booking.totalAmount;
    const bookingAmt = booking.bookingAmount || refundAmount;
    const commission = booking.commissionAmount !== undefined ? booking.commissionAmount : (bookingAmt * 0.05);
    const agentEarning = booking.agentEarning !== undefined ? booking.agentEarning : (bookingAmt - commission);

    // ── Wallet transfer: deduct from agent, credit user ──────────────────────
    const Wallet = require('../models/Wallet');

    // Check agent has enough balance
    let agentWallet = await Wallet.findOne({ ownerId: agentId });
    if (!agentWallet) agentWallet = await Wallet.create({ ownerId: agentId, ownerType: 'AGENT' });

    if (agentWallet.balance < agentEarning) {
      return res.status(400).json({
        success: false,
        message: `Insufficient wallet balance to process refund. Available: PKR ${agentWallet.balance.toFixed(0)}, Required agent contribution: PKR ${agentEarning.toFixed(0)}`
      });
    }

    // Deduct from agent wallet (only deduct their earning portion)
    agentWallet.balance     -= agentEarning;
    agentWallet.totalEarned  = Math.max(0, agentWallet.totalEarned - agentEarning);
    await agentWallet.save();

    // Credit user wallet (full refund amount)
    let userWallet = await Wallet.findOne({ ownerId: booking.userId });
    if (!userWallet) userWallet = await Wallet.create({ ownerId: booking.userId, ownerType: 'USER' });
    userWallet.balance += refundAmount;
    await userWallet.save();

    // ── Update booking ───────────────────────────────────────────────────────
    booking.refundStatus  = 'APPROVED';
    booking.paymentStatus = 'REFUNDED';
    booking.payoutStatus  = 'REFUNDED';
    await booking.save();

    // ── Resolve complaint ────────────────────────────────────────────────────
    const complaint = await Complaint.findOne({ bookingId: booking._id, subject: 'Refund Request' });
    if (complaint) {
      complaint.status = 'RESOLVED';
      complaint.ownerResponse = `Refund approved and PKR ${refundAmount} transferred back to user wallet. ${reason || ''}`;
      await complaint.save();
    }

    // ── Create REFUND and COMMISSION REVERSAL transaction records ────────────
    const refundTransactionId = `REF-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    // User Refund Transaction
    await Transaction.create({
      agentId:         booking.agentId._id,
      bookingId:       booking._id,
      packageId:       booking.packageId._id,
      userId:          booking.userId,
      type:            'REFUND',
      amount:          refundAmount,
      commissionRate:  0,
      commissionAmount: 0,
      payoutStatus:    'PAID',
      paymentMethod:   'CARD',
      paymentDetails:  { transactionId: refundTransactionId },
      notes:           reason || 'Refund approved by agent — amount returned to user wallet'
    });

    // Commission Reversal Transaction
    await Transaction.create({
      agentId:         booking.agentId._id,
      bookingId:       booking._id,
      packageId:       booking.packageId._id,
      userId:          booking.userId,
      type:            'COMMISSION',
      amount:          -commission,
      commissionRate:  5,
      commissionAmount: -commission,
      payoutStatus:    'FAILED',
      paymentMethod:   'CARD',
      paymentDetails:  { transactionId: refundTransactionId },
      notes:           'Platform commission reversed due to refund'
    });

    // Mark original EARNING transaction as reversed/failed
    const originalTxn = await Transaction.findOne({ bookingId: booking._id, type: 'EARNING' });
    if (originalTxn) {
      originalTxn.payoutStatus = 'FAILED';
      originalTxn.notes = 'Reversed — refund issued to user';
      await originalTxn.save();
    }

    // Safe decrement of totalBookings
    const agentForUpdate = await Agent.findById(booking.agentId._id);
    if (agentForUpdate) {
      agentForUpdate.totalBookings = Math.max(0, (agentForUpdate.totalBookings || 0) - 1);
      await agentForUpdate.save();
    }

    // ── Notify user ──────────────────────────────────────────────────────────
    try {
      const Notification = require('../models/Notification');
      const pkg = await Package.findById(booking.packageId._id).select('title');
      await Notification.create({
        recipientId:   booking.userId,
        recipientType: 'USER',
        title:         'Refund Processed ✅',
        message:       `Your refund of PKR ${refundAmount} for "${pkg?.title || 'a package'}" has been approved and credited to your wallet.`,
        type:          'REFUND_APPROVED',
        refId:         booking._id,
        refType:       'Booking'
      });
    } catch (_) {}

    res.json({
      success: true,
      message: `Refund of PKR ${refundAmount} processed successfully. Amount credited to user wallet.`,
      booking,
      refundId:       refundTransactionId,
      refundAmount,
      agentNewBalance: agentWallet.balance,
      userNewBalance:  userWallet.balance,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.rejectRefund = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { reason } = req.body;
    const agentId = req.user.id;

    const booking = await Booking.findById(bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found'
      });
    }

    if (booking.agentId.toString() !== agentId.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    if (booking.refundStatus !== 'REQUESTED') {
      return res.status(400).json({
        success: false,
        message: 'Refund not requested'
      });
    }

    booking.refundStatus = 'REJECTED';
    booking.status = 'CONFIRMED';
    await booking.save();

    const complaint = await Complaint.findOne({
      bookingId: booking._id,
      subject: 'Refund Request'
    });

    if (complaint) {
      complaint.status = 'RESOLVED';
      complaint.ownerResponse = `Refund rejected: ${reason || 'No specific reason provided'}`;
      await complaint.save();
    }

    res.json({
      success: true,
      message: 'Refund rejected successfully',
      booking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getMyRefundRequests = async (req, res) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;

    let query = { userId, refundStatus: { $ne: 'NONE' } };
    if (status) {
      query.refundStatus = status;
    }

    const bookings = await Booking.find(query)
      .populate('packageId', 'title location price')
      .populate('agentId', 'fullName businessName')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      refundRequests: bookings,
      total: bookings.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getAllRefundRequests = async (req, res) => {
  try {
    const { status, limit = 50, skip = 0 } = req.query;

    let query = { refundStatus: { $ne: 'NONE' } };
    if (status) {
      query.refundStatus = status;
    }

    const bookings = await Booking.find(query)
      .populate('userId', 'fullName email phone')
      .populate('packageId', 'title location price')
      .populate('agentId', 'fullName businessName')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await Booking.countDocuments(query);

    res.json({
      success: true,
      refundRequests: bookings,
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

exports.getRefundStats = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = new mongoose.Types.ObjectId(agentId);

    const stats = await Booking.aggregate([
      {
        $match: {
          agentId: agentObjectId,
          refundStatus: { $ne: 'NONE' }
        }
      },
      {
        $group: {
          _id: '$refundStatus',
          count: { $sum: 1 },
          totalAmount: { $sum: '$totalAmount' }
        }
      }
    ]);

    const summary = {
      REQUESTED: 0,
      APPROVED: 0,
      REJECTED: 0
    };

    stats.forEach(stat => {
      summary[stat._id] = {
        count: stat.count,
        totalAmount: stat.totalAmount
      };
    });

    const totalRequested = stats
      .filter(s => s._id === 'REQUESTED')
      .reduce((sum, s) => sum + s.totalAmount, 0);

    const totalApproved = stats
      .filter(s => s._id === 'APPROVED')
      .reduce((sum, s) => sum + s.totalAmount, 0);

    res.json({
      success: true,
      stats: summary,
      overview: {
        totalRefunded: totalApproved,
        pendingRefunds: totalRequested
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
