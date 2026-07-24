const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent',
    required: true
  },

  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking'
  },

  packageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Package'
  },

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },

  type: {
    type: String,
    enum: ['EARNING', 'COMMISSION', 'PAYOUT', 'REFUND', 'SUBSCRIPTION'],
    required: true
  },

  amount: {
    type: Number,
    required: true
  },

  commissionRate: {
    type: Number,
    default: 0
  },

  commissionAmount: {
    type: Number,
    default: 0
  },

  payoutStatus: {
    type: String,
    enum: ['PENDING', 'APPROVED', 'PAID', 'FAILED'],
    default: 'PENDING'
  },

  paymentMethod: {
    type: String,
    enum: ['CARD', 'JAZZCASH', 'EASYPAISA', 'BANK', 'WALLET']
  },

  paymentDetails: {
    transactionId: String,
    bankAccount: String,
    jazzCashNumber: String,
    easyPaisaNumber: String
  },

  processedDate: {
    type: Date
  },

  notes: {
    type: String
  }

}, { timestamps: true });

module.exports = mongoose.model('Transaction', transactionSchema);
