const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({

  // -------- Relationships --------
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent',
    required: true
  },

  packageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Package',
    required: true
  },

  // -------- Travel Details --------
  seats: {
    type: Number,
    required: true
  },

  travelDate: {
    type: Date,
    required: true
  },

  // -------- Payment --------
  totalAmount: {
    type: Number,
    required: true
  },

  paymentStatus: {
    type: String,
    enum: ['PENDING', 'PAID', 'REFUNDED'],
    default: 'PENDING'
  },

  paymentMethod: {
    type: String,
    default: 'CARD'
  },

  // -------- Financial Fields for 5% Commission --------
  bookingAmount: {
    type: Number
  },
  commissionPercentage: {
    type: Number,
    default: 5
  },
  commissionAmount: {
    type: Number
  },
  agentEarning: {
    type: Number
  },
  ownerRevenue: {
    type: Number
  },
  payoutStatus: {
    type: String,
    enum: ['PENDING', 'PAID', 'REFUNDED'],
    default: 'PENDING'
  },

  // -------- Booking State --------
  status: {
    type: String,
    enum: ['CONFIRMED', 'CANCELLED', 'COMPLETED'],
    default: 'CONFIRMED'
  },

  // -------- System Tracking --------
  cancellationReason: String,
  refundStatus: {
    type: String,
    enum: ['NONE', 'REQUESTED', 'APPROVED', 'REJECTED'],
    default: 'NONE'
  }

}, { timestamps: true });

module.exports = mongoose.model('Booking', bookingSchema);
