const Booking = require('../models/Booking');
const Package = require('../models/Package');
const User = require('../models/User');
const { calculateCommission } = require('../utils/commission');

// ---------- CREATE ----------
exports.createBooking = async (req, res) => {
  try {
    const { packageId, seats, travelDate, paymentMethod, cardId } = req.body;

    if (!packageId || !seats || !travelDate || !paymentMethod) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: packageId, seats, travelDate, and paymentMethod are required'
      });
    }

    if (seats <= 0) {
      return res.status(400).json({ success: false, message: 'Seats must be a positive number' });
    }

    const pkg = await Package.findById(packageId);
    if (!pkg) return res.status(404).json({ success: false, message: 'Package not found' });

    if (pkg.availableSeats < seats) {
      return res.status(400).json({
        success: false,
        message: `Not enough seats available. Only ${pkg.availableSeats} seats remaining.`
      });
    }

    const totalAmount = pkg.price * seats;

    // ── Wallet payment: deduct from user, credit agent ───────────────────────
    const Wallet = require('../models/Wallet');

    // Fix: use findOne then create separately — never use await X || await Y
    let userWallet = await Wallet.findOne({ ownerId: req.user.id });
    if (!userWallet) {
      userWallet = await Wallet.create({ ownerId: req.user.id, ownerType: 'USER' });
    }

    // Validate card if provided
    if (cardId) {
      const card = userWallet.cards.find(c => c._id.toString() === cardId);
      if (!card) return res.status(404).json({ success: false, message: 'Card not found in wallet' });
    }

    // Credit agent (95%) — platform keeps 5% commission
    const { commission: commissionAmount, netAgentEarning: agentEarning } = calculateCommission(totalAmount);
    const commissionRate = 5;

    let agentWallet = await Wallet.findOne({ ownerId: pkg.agentId });
    if (!agentWallet) {
      agentWallet = await Wallet.create({ ownerId: pkg.agentId, ownerType: 'AGENT' });
    }
    agentWallet.balance     += agentEarning;
    agentWallet.totalEarned += agentEarning;
    await agentWallet.save();

    // Credit owner wallet with 5% commission
    const Owner = require('../models/Owner');
    try {
      const owner = await Owner.findOne({});
      if (owner) {
        let ownerWallet = await Wallet.findOne({ ownerId: owner._id });
        if (!ownerWallet) ownerWallet = await Wallet.create({ ownerId: owner._id, ownerType: 'OWNER' });
        ownerWallet.balance     += commissionAmount;
        ownerWallet.totalEarned += commissionAmount;
        await ownerWallet.save();
      }
    } catch (_) {}

    // ── Create booking ───────────────────────────────────────────────────────
    const booking = await Booking.create({
      userId: req.user.id,
      agentId: pkg.agentId,
      packageId,
      seats,
      travelDate,
      totalAmount,
      bookingAmount: totalAmount,
      commissionPercentage: commissionRate,
      commissionAmount,
      agentEarning,
      ownerRevenue: commissionAmount,
      payoutStatus: 'PENDING',
      paymentMethod: 'CARD',
      paymentStatus: 'PAID'
    });

    // ── Create transaction record ────────────────────────────────────────────
    // amount = full amount user paid; agentEarning shown separately
    const Transaction = require('../models/Transaction');
    const transactionId = `TXN-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    await Transaction.create({
      agentId: pkg.agentId,
      bookingId: booking._id,
      packageId,
      userId: req.user.id,
      type: 'EARNING',
      amount: agentEarning,
      commissionRate: commissionRate,
      commissionAmount,
      payoutStatus: 'PENDING',
      paymentMethod: 'CARD',
      paymentDetails: { transactionId }
    });

    await Transaction.create({
      agentId: pkg.agentId,
      bookingId: booking._id,
      packageId,
      userId: req.user.id,
      type: 'COMMISSION',
      amount: commissionAmount,
      commissionRate: commissionRate,
      commissionAmount,
      payoutStatus: 'PAID',
      paymentMethod: 'CARD',
      paymentDetails: { transactionId }
    });

    await Package.findByIdAndUpdate(packageId, { $inc: { availableSeats: -seats } });
    await User.findByIdAndUpdate(req.user.id, { $inc: { totalBookings: 1 } });
    const Agent = require('../models/Agent');
    await Agent.findByIdAndUpdate(pkg.agentId, { $inc: { totalBookings: 1 } });

    res.status(201).json({
      success: true,
      booking,
      walletBalance: userWallet.balance,
      transactionId
    });
  } catch (error) {
    console.error('🔴 Create booking error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create booking. Please try again.',
      error: error.message
    });
  }
};

// ---------- USER BOOKINGS ----------
exports.getUserBookings = async (req, res) => {
  const bookings = await Booking.find({ userId: req.user.id })
    .populate('packageId', 'title price location image images duration')
    .sort({ createdAt: -1 });
  res.json({ success: true, bookings });
};

// ---------- CANCEL ----------
exports.cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }

    const requesterId = (req.user && req.user.id) ? req.user.id.toString() : '';
    const userRole = (req.user && req.user.role) ? req.user.role : '';

    const bookingUserId = booking.userId
      ? (booking.userId._id ? booking.userId._id.toString() : booking.userId.toString())
      : '';
    const bookingAgentId = booking.agentId
      ? (booking.agentId._id ? booking.agentId._id.toString() : booking.agentId.toString())
      : '';

    const isOwner = bookingUserId && (bookingUserId === requesterId);
    const isAgent = bookingAgentId && (bookingAgentId === requesterId);
    const isAdminOrSystemOwner = userRole === 'OWNER' || userRole === 'ADMIN';

    if (!isOwner && !isAgent && !isAdminOrSystemOwner) {
      return res.status(403).json({ success: false, message: 'Unauthorized to cancel this booking' });
    }

    if (booking.status === 'CANCELLED') {
      return res.json({ success: true, message: 'Booking is already cancelled.' });
    }

    booking.status = 'CANCELLED';
    booking.refundStatus = 'REQUESTED';
    if (req.body && req.body.cancellationReason) {
      booking.cancellationReason = req.body.cancellationReason;
    }
    await booking.save();

    // Restore available seats
    if (booking.packageId && booking.seats) {
      await Package.findByIdAndUpdate(booking.packageId, {
        $inc: { availableSeats: booking.seats }
      });
    }

    // Notify the user that their booking was cancelled
    try {
      const Notification = require('../models/Notification');
      const pkg = await Package.findById(booking.packageId).select('title');
      await Notification.create({
        recipientId: booking.userId,
        recipientType: 'USER',
        title: 'Booking Cancelled',
        message: `Your booking for "${pkg?.title || 'a package'}" has been cancelled. A refund request has been automatically initiated. Please visit the Refund Request page to complete your refund.`,
        type: 'BOOKING_CANCELLED',
        refId: booking._id,
        refType: 'Booking'
      });
    } catch (notifErr) {
      console.warn('⚠️ Could not send cancellation notification:', notifErr.message);
    }

    return res.json({ success: true, message: 'Booking cancelled. Refund initiated.' });
  } catch (error) {
    console.error('🔴 cancelBooking Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to cancel booking',
      error: error.message,
    });
  }
};

// ---------- AGENT BOOKINGS ----------
exports.getAgentBookings = async (req, res) => {
  const bookings = await Booking.find({ agentId: req.user.id }).populate('userId packageId');
  res.json({ success: true, bookings });
};

// ---------- OWNER BOOKINGS ----------
exports.getAllBookings = async (req, res) => {
  const bookings = await Booking.find().populate('userId agentId packageId');
  res.json({ success: true, bookings });
};
