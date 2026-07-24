const mongoose = require('mongoose');

const ownerSchema = new mongoose.Schema({

  // ---------- Basic Info ----------
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

  // ---------- System Role ----------
  role: {
    type: String,
    enum: ['OWNER'],
    default: 'OWNER'
  },

  // ---------- owner Controls ----------
  canVerifyAgents: {
    type: Boolean,
    default: true
  },

  canManageUsers: {
    type: Boolean,
    default: true
  },

  canManageSystem: {
    type: Boolean,
    default: true
  },

  // ---------- Dashboard Analytics ----------
  lastLogin: Date,
  actionsLog: [{
    action: String,
    target: String,
    date: { type: Date, default: Date.now }
  }]

}, { timestamps: true });

module.exports = mongoose.model('Owner', ownerSchema);
