const mongoose = require('mongoose');

const complaintSchema = new mongoose.Schema({

  // ---------- Relations ----------
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent'
  },

  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Booking'
  },

  // ---------- Complaint Content ----------
  subject: {
    type: String,
    required: true
  },

  description: {
    type: String,
    required: true
  },

  // ---------- Workflow ----------
  // OPEN       → user submitted, owner has not yet forwarded
  // IN_PROGRESS → owner forwarded to agent, agent working on it
  // RESOLVED   → agent marked as resolved (or owner resolved directly)
  status: {
    type: String,
    enum: ['OPEN', 'IN_PROGRESS', 'RESOLVED'],
    default: 'OPEN'
  },

  // Set to true when owner forwards the complaint to the agent
  forwardedToAgent: {
    type: Boolean,
    default: false
  },

  // owner's message when forwarding / responding
  ownerResponse: {
    type: String,
    default: ''
  },

  // Agent's resolution response
  agentResponse: {
    type: String,
    default: ''
  }

}, { timestamps: true });

module.exports = mongoose.model('Complaint', complaintSchema);
