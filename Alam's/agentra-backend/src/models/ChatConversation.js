const mongoose = require('mongoose');

const chatConversationSchema = new mongoose.Schema({

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent'
  },

  sessionId: {
    type: String,
    required: true,
    unique: true
  },

  messages: [{
    role: {
      type: String,
      enum: ['USER', 'BOT', 'AGENT'],
      required: true
    },
    content: {
      type: String,
      required: true
    },
    timestamp: {
      type: Date,
      default: Date.now
    },
    packageReference: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Package'
    }
  }],

  status: {
    type: String,
    enum: ['ACTIVE', 'CLOSED', 'TRANSFERRED'],
    default: 'ACTIVE'
  },

  satisfaction: {
    type: Number,
    min: 1,
    max: 5
  },

  tags: [String]

}, { timestamps: true });

module.exports = mongoose.model('ChatConversation', chatConversationSchema);
