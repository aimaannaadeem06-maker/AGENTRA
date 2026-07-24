const mongoose = require('mongoose');

/**
 * Wallet — stores mock card details and balance for both Users and Agents.
 * This is a mock/demo payment system (like Fiverr's internal wallet).
 * Card numbers are stored as-is for demo purposes only — never do this in production.
 */
const walletSchema = new mongoose.Schema({

  ownerId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    index: true
  },

  ownerType: {
    type: String,
    enum: ['USER', 'AGENT', 'OWNER'],
    required: true
  },

  // Current spendable balance (PKR)
  balance: {
    type: Number,
    default: 50000   // Every new wallet starts with PKR 50,000 mock funds
  },

  // Total ever earned (agents only)
  totalEarned: {
    type: Number,
    default: 0
  },

  // Total ever withdrawn (agents only)
  totalWithdrawn: {
    type: Number,
    default: 0
  },

  // Saved card details (mock — last 4 digits stored for display)
  cards: [{
    cardHolderName: { type: String, required: true },
    cardNumber:     { type: String, required: true },   // full number stored for mock
    last4:          { type: String, required: true },   // last 4 digits for display
    expiryMonth:    { type: String, required: true },
    expiryYear:     { type: String, required: true },
    cardType:       { type: String, enum: ['VISA', 'MASTERCARD', 'OTHER'], default: 'VISA' },
    isDefault:      { type: Boolean, default: false },
    addedAt:        { type: Date, default: Date.now }
  }],

  // Withdrawal bank account (agents only)
  bankAccount: {
    accountTitle:  { type: String, default: '' },
    accountNumber: { type: String, default: '' },
    bankName:      { type: String, default: '' },
    iban:          { type: String, default: '' }
  }

}, { timestamps: true });

module.exports = mongoose.model('Wallet', walletSchema);
