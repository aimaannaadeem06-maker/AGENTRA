const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({

  // ---------- Relations ----------
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

  // ---------- Review Content ----------
  rating: {
    type: Number,
    min: 1,
    max: 5,
    required: true
  },

  comment: {
    type: String,
    default: ''
  },

  // ---------- Moderation ----------
  isApproved: {
    type: Boolean,
    default: true
  }

}, { timestamps: true });

module.exports = mongoose.model('Review', reviewSchema);
