const fs = require('fs');
const Booking = require('../models/Booking');
const Review = require('../models/Review');
const Transaction = require('../models/Transaction');
const Complaint = require('../models/Complaint');
const Package = require('../models/Package');
const User = require('../models/User');
const Agent = require('../models/Agent');

// ================= PROFILE =================
exports.getProfile = async (req, res) => {
  const user = await User.findById(req.user.id).select('-password');
  res.json({ success: true, user });
};

exports.updateProfile = async (req, res) => {
  const updated = await User.findByIdAndUpdate(req.user.id, req.body, { new: true });
  res.json({ success: true, user: updated });
};

exports.uploadProfileImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    let imagePath = `/uploads/profiles/${req.file.filename}`;

    // 1. Try uploading to Cloudinary
    try {
      const cloudinary = require('cloudinary').v2;
      cloudinary.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'dk66ra1nm',
        api_key: process.env.CLOUDINARY_API_KEY || '553274952984634',
        api_secret: process.env.CLOUDINARY_API_SECRET || 'cvKaOOZznsXa9yrqiggPhcoYr7U',
      });
      const filePath = req.file.path;
      if (filePath && fs.existsSync(filePath)) {
        const result = await cloudinary.uploader.upload(filePath, {
          folder: 'agentra/profiles',
        });
        if (result && result.secure_url) {
          imagePath = result.secure_url;
        }
      }
    } catch (cErr) {
      console.warn('⚠️ Cloudinary profile upload failed, falling back to base64 data URI:', cErr.message);
      if (req.file.buffer) {
        const mimeType = req.file.mimetype || 'image/jpeg';
        imagePath = `data:${mimeType};base64,${req.file.buffer.toString('base64')}`;
      } else if (req.file.path && fs.existsSync(req.file.path)) {
        const fileData = fs.readFileSync(req.file.path);
        const mimeType = req.file.mimetype || 'image/jpeg';
        imagePath = `data:${mimeType};base64,${fileData.toString('base64')}`;
      }
    }

    console.log('📤 Profile image saved:', imagePath.substring(0, 50), 'for user:', req.user.id);
    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { profileImage: imagePath },
      { new: true }
    ).select('-password');

    res.json({ success: true, url: imagePath, user: updatedUser });
  } catch (err) {
    console.error('🔴 Upload profile image error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= BOOKINGS =================
exports.createBooking = async (req, res) => {
  try {
    const { packageId, seats, travelDate, paymentMethod = 'CARD' } = req.body;

    if (!packageId || !seats || !travelDate) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: packageId, seats, and travelDate are required',
      });
    }

    if (seats <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Seats must be a positive number',
      });
    }

    const pkg = await Package.findById(packageId);
    if (!pkg) return res.status(404).json({ success: false, message: "Package not found" });

    if (pkg.availableSeats < seats)
      return res.status(400).json({ success: false, message: "Not enough seats available" });

    const totalAmount = seats * pkg.price;

    const booking = await Booking.create({
      userId: req.user.id,
      agentId: pkg.agentId,
      packageId,
      seats,
      totalAmount,
      travelDate,
      paymentMethod,
      paymentStatus: 'PAID',
    });

    // Create a transaction record for payment history
    await Transaction.create({
      agentId: pkg.agentId,
      bookingId: booking._id,
      packageId: packageId,
      userId: req.user.id,
      type: 'EARNING',
      amount: totalAmount,
      paymentMethod,
      payoutStatus: 'PENDING',
      notes: `Booking for ${pkg.title}`
    });

    await Package.findByIdAndUpdate(packageId, { $inc: { availableSeats: -seats } });
    await User.findByIdAndUpdate(req.user.id, { 
      $inc: { 
        totalBookings: 1,
        rewardPoints: 100 // Reward 100 points per booking
      } 
    });

    res.status(201).json({ success: true, booking });

  } catch (err) {
    console.error('🔴 Create booking error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getUserBookings = async (req, res) => {
  const bookings = await Booking.find({ userId: req.user.id })
    .populate('packageId', 'title price location image images duration')
    .sort({ createdAt: -1 });
  res.json({ success: true, bookings });
};

// ================= REVIEWS =================
exports.createReview = async (req, res) => {
  const { packageId, rating, comment } = req.body;

  const pkg = await Package.findById(packageId);
  if (!pkg) return res.status(404).json({ message: "Package not found" });

  const review = await Review.create({
    userId: req.user.id,
    agentId: pkg.agentId,
    packageId,
    rating,
    comment
  });

  const reviews = await Review.find({ agentId: pkg.agentId });
  const avg = reviews.reduce((a, b) => a + b.rating, 0) / reviews.length;

  await Agent.findByIdAndUpdate(pkg.agentId, { averageRating: avg });

  res.status(201).json({ success: true, review });
};

exports.getUserReviews = async (req, res) => {
  const { packageId } = req.query;

  // Compatibility: frontend calls /users/reviews?packageId=... publicly.
  if (packageId) {
    const reviews = await Review.find({ packageId })
      .populate('userId', 'fullName profileImage')
      .populate('packageId');
    return res.json({ success: true, reviews });
  }

  if (!req.user?.id) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }

  const reviews = await Review.find({ userId: req.user.id }).populate('packageId');
  return res.json({ success: true, reviews });
};

// ================= COMPLAINTS =================
exports.raiseComplaint = async (req, res) => {
  try {
    const { bookingId, subject, description } = req.body;

    // Derive agentId from the booking so complaint is routed to the correct agent
    let agentId;
    if (bookingId) {
      const booking = await Booking.findById(bookingId);
      if (booking) agentId = booking.agentId;
    }

    const complaint = await Complaint.create({
      userId: req.user.id,
      agentId,
      bookingId,
      subject,
      description
    });

    res.status(201).json({ success: true, complaint });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getUserComplaints = async (req, res) => {
  try {
    const complaints = await Complaint.find({ userId: req.user.id })
      .populate('agentId', 'fullName businessName')
      .populate('bookingId', 'totalAmount travelDate')
      .sort({ createdAt: -1 });
    res.json({ success: true, complaints });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= AI PREFERENCES =================
exports.updatePreferences = async (req, res) => {
  const updated = await User.findByIdAndUpdate(
    req.user.id,
    { preferences: req.body },
    { new: true }
  );
  res.json({ success: true, preferences: updated.preferences });
};

// ================= FAVORITES =================
exports.toggleFavorite = async (req, res) => {
  try {
    const { packageId } = req.body;
    const user = await User.findById(req.user.id);
    
    const isFavorite = user.favorites.includes(packageId);
    if (isFavorite) {
      user.favorites.pull(packageId);
    } else {
      user.favorites.push(packageId);
    }
    
    await user.save();
    res.json({ success: true, isFavorite: !isFavorite });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getFavorites = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).populate('favorites');
    res.json({ success: true, favorites: user.favorites });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= ACCOUNT =================
exports.deactivateAccount = async (req, res) => {
  await User.findByIdAndUpdate(req.user.id, { isActive: false });
  res.json({ success: true, message: "Account deactivated" });
};
