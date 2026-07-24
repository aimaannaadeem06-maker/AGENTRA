const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({

  // -------- Basic Account Info --------
  fullName: {
    type: String,
    required: true,
    trim: true
  },

  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true
  },

  password: {
    type: String,
    required: true
  },

  phone: {
    type: String,
    required: true,
    unique: true
  },

  profileImage: {
    type: String,
    default: ''
  },

  // -------- System Role (FIXED) --------
  role: {
    type: String,
    enum: ['USER', 'AGENT', 'owner'],
    default: 'USER'
  },

  // -------- Approval Status (ADD THIS) --------
  status: {
    type: String,
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    default: 'APPROVED'
  },

  // -------- Travel & Booking Data --------
  totalBookings: {
    type: Number,
    default: 0
  },

  rewardPoints: {
    type: Number,
    default: 0
  },

  favorites: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Package'
  }],

  travelHistory: [{
    packageId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Package'
    },
    bookingDate: Date,
    travelDate: Date
  }],

  // -------- AI Personalization --------
  preferences: {
    budget: {
      min: Number,
      max: Number
    },
    preferredLocations: [String],
    travelStyle: {
      type: String,
      enum: ['SOLO', 'FAMILY', 'COUPLE', 'GROUP'],
      default: 'SOLO'
    },
    interests: [String]
  },

  // -------- Account Control --------
  isActive: {
    type: Boolean,
    default: true
  },

  emailVerified: {
    type: Boolean,
    default: false
  },

  emailVerificationToken: {
    type: String
  },

  resetPasswordToken: {
    type: String
  },

  resetPasswordExpires: {
    type: Date
  },

}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
