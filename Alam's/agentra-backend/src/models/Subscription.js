const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema({

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent',
    required: true,
    unique: true
  },

  plan: {
    type: String,
    enum: ['FREE', 'MONTHLY', 'YEARLY'],
    default: 'FREE'
  },

  status: {
    type: String,
    enum: ['ACTIVE', 'CANCELLED', 'EXPIRED', 'PENDING'],
    default: 'PENDING'
  },

  startDate: {
    type: Date,
    default: Date.now
  },

  endDate: {
    type: Date
  },

  paymentMethod: {
    type: String,
    enum: ['CARD', 'JAZZCASH', 'EASYPAISA', 'BANK'],
    required: true
  },

  paymentId: {
    type: String
  },

  amount: {
    type: Number,
    required: true
  },

  autoRenew: {
    type: Boolean,
    default: false
  },

  features: [{
    name: String,
    isActive: Boolean
  }],

  aiToolsAccess: {
    salesAgent: { type: Boolean, default: false },
    chatbot: { type: Boolean, default: false },
    analytics: { type: Boolean, default: false }
  }

}, { timestamps: true });

module.exports = mongoose.model('Subscription', subscriptionSchema);
