const mongoose = require('mongoose');

const analyticsSchema = new mongoose.Schema({

  packageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Package',
    required: true
  },

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent',
    required: true
  },

  views: {
    type: Number,
    default: 0
  },

  clicks: {
    type: Number,
    default: 0
  },

  bookings: {
    type: Number,
    default: 0
  },

  conversionRate: {
    type: Number,
    default: 0
  },

  revenue: {
    type: Number,
    default: 0
  },

  date: {
    type: Date,
    default: Date.now
  }

}, { timestamps: true });

analyticsSchema.index({ packageId: 1, date: -1 });
analyticsSchema.index({ agentId: 1, date: -1 });

module.exports = mongoose.model('Analytics', analyticsSchema);
