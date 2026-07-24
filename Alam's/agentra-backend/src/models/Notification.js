const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  // Who receives this notification
  recipientId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true
  },

  recipientType: {
    type: String,
    enum: ['AGENT', 'USER'],
    required: true
  },

  title: {
    type: String,
    required: true
  },

  message: {
    type: String,
    required: true
  },

  type: {
    type: String,
    enum: ['ACCOUNT_BLOCKED', 'ACCOUNT_DELETED', 'BOOKING_CANCELLED',
           'BOOKING_CONFIRMED', 'REFUND_APPROVED', 'REFUND_REJECTED', 'GENERAL'],
    default: 'GENERAL'
  },

  isRead: {
    type: Boolean,
    default: false
  },

  // Optional reference data
  refId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null
  },

  refType: {
    type: String,
    default: null
  }

}, { timestamps: true });

module.exports = mongoose.model('Notification', notificationSchema);
