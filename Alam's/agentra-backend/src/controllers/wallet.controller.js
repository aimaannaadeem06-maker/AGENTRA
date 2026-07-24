/**
 * wallet.controller.js
 *
 * Mock Fiverr-style wallet system.
 * - Users have a wallet with a card balance (PKR 50,000 default).
 * - When a user books a package, the amount is deducted from their wallet.
 * - The agent's wallet is credited with 85% (platform keeps 15% commission).
 * - Agents can withdraw their available balance to their saved bank account.
 */

const Wallet   = require('../models/Wallet');
const Booking  = require('../models/Booking');
const Package  = require('../models/Package');
const Transaction = require('../models/Transaction');
const { calculateCommission } = require('../utils/commission');

// ── helpers ───────────────────────────────────────────────────────────────────

function detectCardType(number) {
  const n = number.replace(/\s/g, '');
  if (/^4/.test(n))          return 'VISA';
  if (/^5[1-5]/.test(n))     return 'MASTERCARD';
  if (/^2[2-7]/.test(n))     return 'MASTERCARD';
  return 'OTHER';
}

async function getOrCreateWallet(ownerId, ownerType) {
  let wallet = await Wallet.findOne({ ownerId });
  if (!wallet) {
    wallet = await Wallet.create({ ownerId, ownerType });
  }
  return wallet;
}

// ── GET /api/wallet ───────────────────────────────────────────────────────────
exports.getWallet = async (req, res) => {
  try {
    const ownerType = req.user.role === 'AGENT' ? 'AGENT' : 'USER';
    const wallet = await getOrCreateWallet(req.user.id, ownerType);

    // Never expose full card numbers in the response
    const safeCards = wallet.cards.map(c => ({
      _id:            c._id,
      cardHolderName: c.cardHolderName,
      last4:          c.last4,
      expiryMonth:    c.expiryMonth,
      expiryYear:     c.expiryYear,
      cardType:       c.cardType,
      isDefault:      c.isDefault,
      addedAt:        c.addedAt,
    }));

    // Calculate agent dashboard statistics if AGENT
    let totalEarnings = 0;
    let totalCommission = 0;
    let netEarnings = 0;
    let pendingPayouts = 0;

    if (req.user.role === 'AGENT') {
      const mongoose = require('mongoose');
      const agentObjectId = new mongoose.Types.ObjectId(req.user.id);
      const stats = await Transaction.aggregate([
        { $match: { agentId: agentObjectId, type: 'EARNING' } },
        {
          $group: {
            _id: null,
            netEarnings: { $sum: '$amount' },
            totalCommission: { $sum: '$commissionAmount' },
            pendingPayouts: {
              $sum: {
                $cond: [{ $eq: ['$payoutStatus', 'PENDING'] }, '$amount', 0]
              }
            }
          }
        }
      ]);
      if (stats.length > 0) {
        netEarnings = stats[0].netEarnings;
        totalCommission = stats[0].totalCommission;
        pendingPayouts = stats[0].pendingPayouts;
        totalEarnings = netEarnings + totalCommission;
      }
    }

    res.json({
      success: true,
      wallet: {
        balance:        wallet.balance,
        totalEarned:    wallet.totalEarned,
        totalWithdrawn: wallet.totalWithdrawn,
        totalCommissionPaid: totalCommission,
        totalEarnings,
        totalCommission,
        netEarnings,
        pendingPayouts,
        cards:          safeCards,
        bankAccount:    wallet.bankAccount,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── POST /api/wallet/cards ────────────────────────────────────────────────────
exports.addCard = async (req, res) => {
  try {
    const { cardHolderName, cardNumber, expiryMonth, expiryYear, cvv, setDefault } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (!cardHolderName || !cardNumber || !expiryMonth || !expiryYear || !cvv) {
      return res.status(400).json({ success: false, message: 'All card fields are required' });
    }

    const cleaned = cardNumber.replace(/\s/g, '');
    if (cleaned.length < 13 || cleaned.length > 19 || !/^\d+$/.test(cleaned)) {
      return res.status(400).json({ success: false, message: 'Invalid card number — must be 13–19 digits' });
    }

    // Luhn check (basic card number validity)
    let sum = 0, alt = false;
    for (let i = cleaned.length - 1; i >= 0; i--) {
      let n = parseInt(cleaned[i], 10);
      if (alt) { n *= 2; if (n > 9) n -= 9; }
      sum += n;
      alt = !alt;
    }
    if (sum % 10 !== 0) {
      return res.status(400).json({ success: false, message: 'Invalid card number' });
    }

    // Expiry validation
    const month = parseInt(expiryMonth, 10);
    const year  = parseInt(String(expiryYear).length === 2 ? `20${expiryYear}` : expiryYear, 10);
    if (isNaN(month) || month < 1 || month > 12) {
      return res.status(400).json({ success: false, message: 'Invalid expiry month (1–12)' });
    }
    const now = new Date();
    const expDate = new Date(year, month - 1, 1);
    if (expDate < new Date(now.getFullYear(), now.getMonth(), 1)) {
      return res.status(400).json({ success: false, message: 'Card has expired' });
    }

    // CVV validation
    const cvvStr = String(cvv).trim();
    if (!/^\d{3,4}$/.test(cvvStr)) {
      return res.status(400).json({ success: false, message: 'CVV must be 3 or 4 digits' });
    }

    // Card holder name — letters and spaces only
    if (!/^[a-zA-Z\s]{2,50}$/.test(cardHolderName.trim())) {
      return res.status(400).json({ success: false, message: 'Card holder name must contain only letters (2–50 chars)' });
    }

    const ownerType = req.user.role === 'AGENT' ? 'AGENT' : 'USER';
    const wallet    = await getOrCreateWallet(req.user.id, ownerType);

    const last4    = cleaned.slice(-4);
    const cardType = detectCardType(cleaned);

    if (setDefault) {
      wallet.cards.forEach(c => { c.isDefault = false; });
    }

    wallet.cards.push({
      cardHolderName: cardHolderName.trim(),
      cardNumber: cleaned,
      last4,
      expiryMonth: String(month).padStart(2, '0'),
      expiryYear:  String(year),
      cardType,
      isDefault: setDefault || wallet.cards.length === 0,
    });

    await wallet.save();

    res.status(201).json({
      success: true,
      message: 'Card added successfully',
      card: { last4, cardType, cardHolderName: cardHolderName.trim(), expiryMonth, expiryYear, isDefault: setDefault || wallet.cards.length === 1 },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── DELETE /api/wallet/cards/:cardId ─────────────────────────────────────────
exports.removeCard = async (req, res) => {
  try {
    const ownerType = req.user.role === 'AGENT' ? 'AGENT' : 'USER';
    const wallet    = await getOrCreateWallet(req.user.id, ownerType);

    const idx = wallet.cards.findIndex(c => c._id.toString() === req.params.cardId);
    if (idx === -1) return res.status(404).json({ success: false, message: 'Card not found' });

    wallet.cards.splice(idx, 1);
    await wallet.save();

    res.json({ success: true, message: 'Card removed' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── POST /api/wallet/pay ──────────────────────────────────────────────────────
/**
 * Deduct amount from user wallet and credit agent wallet.
 * Called after booking is created (or as part of booking creation).
 * Body: { bookingId, cardId? }
 */
exports.payWithWallet = async (req, res) => {
  try {
    const { bookingId, cardId } = req.body;
    const userId = req.user.id;

    const booking = await Booking.findById(bookingId)
      .populate('packageId')
      .populate('agentId');

    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (booking.userId.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, message: 'Unauthorized' });
    }
    if (booking.paymentStatus === 'PAID') {
      return res.status(400).json({ success: false, message: 'Booking already paid' });
    }

    const amount = booking.totalAmount;

    // ── Deduct from user wallet ──────────────────────────────────────────────
    let userWallet = await Wallet.findOne({ ownerId: userId });
    if (!userWallet) userWallet = await Wallet.create({ ownerId: userId, ownerType: 'USER' });

    if (userWallet.balance < amount) {
      return res.status(400).json({
        success: false,
        message: `Insufficient balance. Your wallet has PKR ${userWallet.balance.toFixed(0)} but PKR ${amount.toFixed(0)} is required.`,
      });
    }

    if (cardId) {
      const card = userWallet.cards.find(c => c._id.toString() === cardId);
      if (!card) return res.status(404).json({ success: false, message: 'Card not found' });
    }

    userWallet.balance -= amount;
    await userWallet.save();

    // ── Credit agent wallet (95%) ────────────────────────────────────────────
    const { commission: commissionAmount, netAgentEarning: agentEarning } = calculateCommission(amount);

    let agentWallet = await Wallet.findOne({ ownerId: booking.agentId._id });
    if (!agentWallet) agentWallet = await Wallet.create({ ownerId: booking.agentId._id, ownerType: 'AGENT' });
    agentWallet.balance      += agentEarning;
    agentWallet.totalEarned  += agentEarning;
    await agentWallet.save();

    // ── Update booking ───────────────────────────────────────────────────────
    booking.bookingAmount = amount;
    booking.commissionPercentage = 5;
    booking.commissionAmount = commissionAmount;
    booking.agentEarning = agentEarning;
    booking.ownerRevenue = commissionAmount;
    booking.payoutStatus = 'PENDING';
    booking.paymentStatus = 'PAID';
    booking.status        = 'CONFIRMED';
    booking.paymentMethod = 'CARD';
    await booking.save();

    // ── Create transactions ──────────────────────────────────────────────────
    const txnId = `TXN-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    await Transaction.create({
      agentId:         booking.agentId._id,
      bookingId:       booking._id,
      packageId:       booking.packageId._id,
      userId,
      type:            'EARNING',
      amount:          agentEarning,
      commissionRate:  5,
      commissionAmount,
      payoutStatus:    'PENDING',
      paymentMethod:   'CARD',
      paymentDetails:  { transactionId: txnId },
    });

    await Transaction.create({
      agentId:         booking.agentId._id,
      bookingId:       booking._id,
      packageId:       booking.packageId._id,
      userId,
      type:            'COMMISSION',
      amount:          commissionAmount,
      commissionRate:  5,
      commissionAmount,
      payoutStatus:    'PAID',
      paymentMethod:   'CARD',
      paymentDetails:  { transactionId: txnId },
    });

    res.json({
      success: true,
      message: 'Payment successful',
      transaction: {
        id:          txnId,
        amount,
        agentEarning,
        commission:  commissionAmount,
        newBalance:  userWallet.balance,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── POST /api/wallet/withdraw ─────────────────────────────────────────────────
/**
 * Agent withdraws available balance to their saved bank account.
 * Body: { amount }
 */
exports.withdraw = async (req, res) => {
  try {
    if (req.user.role !== 'AGENT') {
      return res.status(403).json({ success: false, message: 'Only agents can withdraw' });
    }

    const { amount } = req.body;
    if (!amount || amount <= 0) {
      return res.status(400).json({ success: false, message: 'Invalid withdrawal amount' });
    }

    const wallet = await getOrCreateWallet(req.user.id, 'AGENT');

    if (!wallet.bankAccount?.accountNumber) {
      return res.status(400).json({
        success: false,
        message: 'Please add a bank account before withdrawing',
      });
    }

    if (wallet.balance < amount) {
      return res.status(400).json({
        success: false,
        message: `Insufficient balance. Available: PKR ${wallet.balance.toFixed(0)}`,
      });
    }

    wallet.balance        -= amount;
    wallet.totalWithdrawn += amount;
    await wallet.save();

    // Create PAYOUT transaction
    const txnId = `WD-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    await Transaction.create({
      agentId:        req.user.id,
      type:           'PAYOUT',
      amount,
      payoutStatus:   'PAID',
      paymentMethod:  'BANK',
      paymentDetails: {
        transactionId: txnId,
        bankAccount:   wallet.bankAccount.accountNumber,
      },
      processedDate: new Date(),
      notes: `Withdrawal to ${wallet.bankAccount.bankName} — ${wallet.bankAccount.accountNumber}`,
    });

    res.json({
      success: true,
      message: `PKR ${amount.toFixed(0)} withdrawn successfully`,
      newBalance:     wallet.balance,
      totalWithdrawn: wallet.totalWithdrawn,
      transactionId:  txnId,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── PUT /api/wallet/bank-account ──────────────────────────────────────────────
exports.updateBankAccount = async (req, res) => {
  try {
    if (req.user.role !== 'AGENT') {
      return res.status(403).json({ success: false, message: 'Only agents can update bank account' });
    }

    const { accountTitle, accountNumber, bankName, iban } = req.body;

    // ── Validation ────────────────────────────────────────────────────────────
    if (!accountTitle || !accountNumber || !bankName) {
      return res.status(400).json({ success: false, message: 'Account title, account number and bank name are required' });
    }

    if (!/^[a-zA-Z\s]{2,60}$/.test(accountTitle.trim())) {
      return res.status(400).json({ success: false, message: 'Account title must contain only letters (2–60 chars)' });
    }

    if (!/^\d{8,20}$/.test(accountNumber.trim())) {
      return res.status(400).json({ success: false, message: 'Account number must be 8–20 digits' });
    }

    if (accountNumber.trim().length < 8) {
      return res.status(400).json({ success: false, message: 'Account number too short' });
    }

    if (!/^[a-zA-Z\s]{2,50}$/.test(bankName.trim())) {
      return res.status(400).json({ success: false, message: 'Bank name must contain only letters (2–50 chars)' });
    }

    // IBAN validation (optional but if provided must match PK format or generic)
    if (iban && iban.trim().length > 0) {
      const ibanClean = iban.trim().replace(/\s/g, '').toUpperCase();
      if (!/^[A-Z]{2}\d{2}[A-Z0-9]{4,30}$/.test(ibanClean)) {
        return res.status(400).json({ success: false, message: 'Invalid IBAN format (e.g. PK36SCBL0000001123456702)' });
      }
    }

    const wallet = await getOrCreateWallet(req.user.id, 'AGENT');
    wallet.bankAccount = {
      accountTitle:  accountTitle.trim(),
      accountNumber: accountNumber.trim(),
      bankName:      bankName.trim(),
      iban:          iban ? iban.trim().replace(/\s/g, '').toUpperCase() : ''
    };
    await wallet.save();

    res.json({ success: true, message: 'Bank account updated', bankAccount: wallet.bankAccount });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
