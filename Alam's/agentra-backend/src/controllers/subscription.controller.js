const Subscription = require('../models/Subscription');
const Agent = require('../models/Agent');
const Transaction = require('../models/Transaction');
const Wallet = require('../models/Wallet');
const Owner = require('../models/Owner');

const PRICES = {
  MONTHLY: 2499,
  YEARLY: 24999
};

const FEATURES = {
  MONTHLY: [
    { name: 'AI Sales Agent', isActive: true },
    { name: 'AI Chatbot', isActive: true },
    { name: 'Advanced Analytics', isActive: true },
    { name: 'Priority Support', isActive: false }
  ],
  YEARLY: [
    { name: 'AI Sales Agent', isActive: true },
    { name: 'AI Chatbot', isActive: true },
    { name: 'Advanced Analytics', isActive: true },
    { name: 'Priority Support', isActive: true },
    { name: 'Custom Reports', isActive: true },
    { name: 'API Access', isActive: true }
  ]
};

const buildSubscriptionDates = (plan) => {
  const startDate = new Date();
  const endDate = new Date(startDate.getTime());

  if (plan === 'MONTHLY') {
    endDate.setMonth(endDate.getMonth() + 1);
  } else {
    endDate.setFullYear(endDate.getFullYear() + 1);
  }

  return { startDate, endDate };
};

exports.subscribe = async (req, res) => {
  try {
    const { plan, paymentMethod } = req.body;
    const agentId = req.user.id;

    if (!['MONTHLY', 'YEARLY'].includes(plan)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid plan type'
      });
    }

    const existingSubscription = await Subscription.findOne({ agentId });
    if (existingSubscription && existingSubscription.status === 'ACTIVE' && new Date(existingSubscription.endDate) > new Date()) {
      return res.status(400).json({
        success: false,
        message: 'You already have an active subscription'
      });
    }

    const amount = PRICES[plan];
    const paymentId = `PAY-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const { startDate, endDate } = buildSubscriptionDates(plan);

    let subscription;
    if (existingSubscription) {
      existingSubscription.plan = plan;
      existingSubscription.status = 'ACTIVE';
      existingSubscription.startDate = startDate;
      existingSubscription.endDate = endDate;
      existingSubscription.paymentMethod = paymentMethod;
      existingSubscription.paymentId = paymentId;
      existingSubscription.amount = amount;
      existingSubscription.features = FEATURES[plan];
      existingSubscription.aiToolsAccess = {
        salesAgent: true,
        chatbot: true,
        analytics: true
      };
      subscription = await existingSubscription.save();
    } else {
      subscription = await Subscription.create({
        agentId,
        plan,
        status: 'ACTIVE',
        startDate,
        endDate,
        paymentMethod,
        paymentId,
        amount,
        features: FEATURES[plan],
        aiToolsAccess: {
          salesAgent: true,
          chatbot: true,
          analytics: true
        }
      });
    }

    await Agent.findByIdAndUpdate(agentId, {
      'aiSubscription.plan': plan,
      'aiSubscription.isActive': true,
      'aiSubscription.expiryDate': endDate
    });

    // Deduct from Agent wallet
    let agentWallet = await Wallet.findOne({ ownerId: agentId });
    if (!agentWallet) agentWallet = await Wallet.create({ ownerId: agentId, ownerType: 'AGENT' });
    if (agentWallet.balance < amount) {
      return res.status(400).json({ success: false, message: 'Insufficient wallet balance' });
    }
    agentWallet.balance -= amount;
    await agentWallet.save();

    // Credit owner wallet
    const owner = await Owner.findOne({});
    if (owner) {
      let ownerWallet = await Wallet.findOne({ ownerId: owner._id });
      if (!ownerWallet) ownerWallet = await Wallet.create({ ownerId: owner._id, ownerType: 'OWNER' });
      ownerWallet.balance += amount;
      ownerWallet.totalEarned += amount;
      await ownerWallet.save();
    }

    // Create a transaction record for payment history
    await Transaction.create({
      agentId,
      type: 'SUBSCRIPTION',
      amount,
      paymentMethod: paymentMethod || 'CARD',
      paymentDetails: {
        transactionId: paymentId
      },
      processedDate: new Date(),
      payoutStatus: 'PAID',
      notes: `Subscription to ${plan} plan`
    });

    res.status(201).json({
      success: true,
      message: 'Subscription activated successfully',
      subscription
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getCurrentSubscription = async (req, res) => {
  try {
    const agentId = req.user.id;

    const subscription = await Subscription.findOne({ agentId })
      .sort({ createdAt: -1 });

    if (!subscription) {
      return res.status(404).json({
        success: false,
        message: 'No subscription found'
      });
    }

    const daysRemaining = Math.ceil(
      (new Date(subscription.endDate) - new Date()) / (1000 * 60 * 60 * 24)
    );

    res.json({
      success: true,
      subscription: {
        ...subscription.toObject(),
        daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
        isActive: subscription.status === 'ACTIVE' && daysRemaining > 0
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.cancelSubscription = async (req, res) => {
  try {
    const agentId = req.user.id;

    const subscription = await Subscription.findOne({ agentId, status: 'ACTIVE' });

    if (!subscription) {
      return res.status(404).json({
        success: false,
        message: 'No active subscription found'
      });
    }

    subscription.status = 'CANCELLED';
    subscription.autoRenew = false;
    await subscription.save();

    await Agent.findByIdAndUpdate(agentId, {
      'aiSubscription.isActive': false
    });

    res.json({
      success: true,
      message: 'Subscription cancelled successfully',
      subscription
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.upgradeSubscription = async (req, res) => {
  try {
    const { plan, paymentMethod } = req.body;
    const agentId = req.user.id;
    if (!['MONTHLY', 'YEARLY'].includes(plan)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid plan type'
      });
    }

    const existingSubscription = await Subscription.findOne({ agentId, status: 'ACTIVE' });

    if (!existingSubscription) {
      return res.status(404).json({
        success: false,
        message: 'No active subscription found'
      });
    }

    if (existingSubscription.plan === plan) {
      return res.status(400).json({
        success: false,
        message: 'You already have this plan'
      });
    }

    const amount = PRICES[plan] - PRICES[existingSubscription.plan];
    const paymentId = `UPG-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const { startDate, endDate } = buildSubscriptionDates(plan);

    existingSubscription.plan = plan;
    existingSubscription.status = 'ACTIVE';
    existingSubscription.startDate = startDate;
    existingSubscription.endDate = endDate;
    existingSubscription.paymentMethod = paymentMethod;
    existingSubscription.paymentId = paymentId;
    existingSubscription.amount = amount;
    existingSubscription.features = FEATURES[plan];
    existingSubscription.aiToolsAccess = {
      salesAgent: true,
      chatbot: true,
      analytics: true
    };
    const upgradedSubscription = await existingSubscription.save();

    await Agent.findByIdAndUpdate(agentId, {
      'aiSubscription.plan': plan,
      'aiSubscription.isActive': true,
      'aiSubscription.expiryDate': endDate
    });

    // Deduct from Agent wallet (Upgrade)
    let agentWallet = await Wallet.findOne({ ownerId: agentId });
    if (!agentWallet) agentWallet = await Wallet.create({ ownerId: agentId, ownerType: 'AGENT' });
    if (agentWallet.balance < amount) {
      return res.status(400).json({ success: false, message: 'Insufficient wallet balance' });
    }
    agentWallet.balance -= amount;
    await agentWallet.save();

    // Credit owner wallet
    const owner = await Owner.findOne({});
    if (owner) {
      let ownerWallet = await Wallet.findOne({ ownerId: owner._id });
      if (!ownerWallet) ownerWallet = await Wallet.create({ ownerId: owner._id, ownerType: 'OWNER' });
      ownerWallet.balance += amount;
      ownerWallet.totalEarned += amount;
      await ownerWallet.save();
    }

    // Create a transaction record for payment history
    await Transaction.create({
      agentId,
      type: 'SUBSCRIPTION',
      amount,
      paymentMethod: paymentMethod || 'CARD',
      paymentDetails: {
        transactionId: paymentId
      },
      processedDate: new Date(),
      payoutStatus: 'PAID',
      notes: `Upgrade to ${plan} plan`
    });

    res.json({
      success: true,
      message: 'Subscription upgraded successfully',
      subscription: upgradedSubscription
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getSubscriptionPlans = async (req, res) => {
  try {
    res.json({
      success: true,
      plans: [
        {
          name: 'FREE',
          price: 0,
          duration: 'Lifetime',
          features: [
            'Basic package listing',
            'Limited bookings',
            'Standard support'
          ],
          aiToolsAccess: {
            salesAgent: false,
            chatbot: false,
            analytics: false
          }
        },
        {
          name: 'MONTHLY',
          price: PRICES.MONTHLY,
          duration: '1 Month',
          features: [
            'AI Sales Agent',
            'AI Chatbot',
            'Advanced Analytics',
            'Priority support'
          ],
          aiToolsAccess: {
            salesAgent: true,
            chatbot: true,
            analytics: true
          }
        },
        {
          name: 'YEARLY',
          price: PRICES.YEARLY,
          duration: '1 Year',
          savings: 'Save 17%',
          features: [
            'AI Sales Agent',
            'AI Chatbot',
            'Advanced Analytics',
            'Priority Support',
            'Custom Reports',
            'API Access'
          ],
          aiToolsAccess: {
            salesAgent: true,
            chatbot: true,
            analytics: true
          }
        }
      ]
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.checkSubscriptionAccess = async (req, res) => {
  try {
    const agentId = req.user.id;
    const { feature } = req.query;

    const agent = await Agent.findById(agentId).select('aiSubscription');
    const subscription = await Subscription.findOne({ agentId, status: 'ACTIVE' });

    if (!subscription || !agent?.aiSubscription?.isActive) {
      return res.json({
        success: true,
        hasAccess: false,
        message: 'No active subscription'
      });
    }

    let hasAccess = false;
    if (feature === 'salesAgent') {
      hasAccess = subscription.aiToolsAccess.salesAgent;
    } else if (feature === 'chatbot') {
      hasAccess = subscription.aiToolsAccess.chatbot;
    } else if (feature === 'analytics') {
      hasAccess = subscription.aiToolsAccess.analytics;
    } else {
      hasAccess = true;
    }

    const daysRemaining = Math.ceil(
      (new Date(subscription.endDate) - new Date()) / (1000 * 60 * 60 * 24)
    );

    res.json({
      success: true,
      hasAccess,
      plan: subscription.plan,
      daysRemaining: daysRemaining > 0 ? daysRemaining : 0,
      endDate: subscription.endDate
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
