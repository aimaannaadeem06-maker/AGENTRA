const mongoose = require('mongoose');

const agentSchema = new mongoose.Schema({

  // Basic Info
  fullName: {
    type: String,
    required: true,
    trim: true
  },

  businessName: {
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

  cnic: {
    type: String,
    required: true,
    unique: true
  },

  location: {
    type: String,
    default: ''
  },

  bio: {
    type: String,
    default: ''
  },

  profileImage: {
    type: String,
    default: ''
  },

  // Policies
  refundPolicy: {
    type: String,
    default: ''
  },

  cancellationPolicy: {
    type: String,
    default: ''
  },

  // System Control
  role: {
    type: String,
    enum: ['AGENT'],
    default: 'AGENT'
  },

  // Approval Status
  status: {
    type: String,
    enum: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'BLOCKED'],
    default: 'PENDING_APPROVAL'
  },

  rejectionReason: {
    type: String,
    default: ''
  },

  isVerified: {
    type: Boolean,
    default: false
  },

  verificationDocuments: [{
    type: String
  }],

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

  // ── owner Notice / Warning ──────────────────────────────────────
  // Set when owner sends a 30-day notice before blocking or deleting
  noticeSentAt: {
    type: Date,
    default: null
  },

  noticeType: {
    type: String,
    enum: ['block', 'delete', null],
    default: null
  },

  noticeMessage: {
    type: String,
    default: ''
  },

  // Business Stats (used in dashboards)
  totalPackages: {
    type: Number,
    default: 0
  },

  totalBookings: {
    type: Number,
    default: 0
  },

  averageRating: {
    type: Number,
    default: 0
  },

  // AI Tools & Subscription
  aiSubscription: {
    plan: { type: String, enum: ['FREE', 'MONTHLY', 'YEARLY'], default: 'FREE' },
    isActive: { type: Boolean, default: false },
    expiryDate: Date
  }

}, { timestamps: true });

module.exports = mongoose.model('Agent', agentSchema);
