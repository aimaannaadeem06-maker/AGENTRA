const Transaction = require('../models/Transaction');
const Booking = require('../models/Booking');
const Agent = require('../models/Agent');
const mongoose = require('mongoose');

exports.getEarningsOverview = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = new mongoose.Types.ObjectId(agentId);

    const earnings = await Transaction.aggregate([
      {
        $match: {
          agentId: agentObjectId,
          type: 'EARNING'
        }
      },
      {
        $group: {
          _id: null,
          totalEarnings: { $sum: '$amount' },
          totalCommission: { $sum: '$commissionAmount' },
          pendingPayouts: {
            $sum: {
              $cond: [{ $eq: ['$payoutStatus', 'PENDING'] }, '$amount', 0]
            }
          },
          approvedPayouts: {
            $sum: {
              $cond: [{ $eq: ['$payoutStatus', 'APPROVED'] }, '$amount', 0]
            }
          },
          paidPayouts: {
            $sum: {
              $cond: [{ $eq: ['$payoutStatus', 'PAID'] }, '$amount', 0]
            }
          },
          totalBookings: { $sum: 1 }
        }
      }
    ]);

    const stats = earnings[0] || {
      totalEarnings: 0,
      totalCommission: 0,
      pendingPayouts: 0,
      approvedPayouts: 0,
      paidPayouts: 0,
      totalBookings: 0
    };

    res.json({
      success: true,
      overview: stats
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getCommissionBreakdown = async (req, res) => {
  try {
    const agentId = req.user.id;
    const { startDate, endDate } = req.query;

    const matchQuery = {
      agentId: agentId,
      type: 'EARNING'
    };

    if (startDate && endDate) {
      matchQuery.createdAt = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const commissions = await Transaction.find(matchQuery)
      .populate('packageId', 'title location price')
      .populate('bookingId', 'status travelDate')
      .populate('userId', 'fullName email')
      .sort({ createdAt: -1 });

    const totalCommission = commissions.reduce(
      (sum, t) => sum + t.commissionAmount,
      0
    );

    const averageCommission = commissions.length > 0
      ? totalCommission / commissions.length
      : 0;

    res.json({
      success: true,
      breakdown: {
        commissions,
        totalCommission,
        averageCommission: averageCommission.toFixed(2),
        count: commissions.length
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getEarningsByPackage = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = new mongoose.Types.ObjectId(agentId);

    const earningsByPackage = await Transaction.aggregate([
      {
        $match: {
          agentId: agentObjectId,
          type: 'EARNING'
        }
      },
      {
        $group: {
          _id: '$packageId',
          totalEarnings: { $sum: '$amount' },
          totalCommission: { $sum: '$commissionAmount' },
          bookings: { $sum: 1 }
        }
      },
      {
        $lookup: {
          from: 'packages',
          localField: '_id',
          foreignField: '_id',
          as: 'package'
        }
      },
      {
        $unwind: '$package'
      },
      {
        $project: {
          package: {
            _id: '$package._id',
            title: '$package.title',
            location: '$package.location',
            price: '$package.price'
          },
          totalEarnings: 1,
          totalCommission: 1,
          bookings: 1
        }
      },
      {
        $sort: { totalEarnings: -1 }
      }
    ]);

    res.json({
      success: true,
      earningsByPackage
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getPayoutHistory = async (req, res) => {
  try {
    const agentId = req.user.id;
    const { status, limit = 20, skip = 0 } = req.query;

    const query = {
      agentId: agentId,
      type: { $in: ['EARNING', 'COMMISSION', 'PAYOUT', 'REFUND', 'SUBSCRIPTION'] }
    };

    if (status) {
      query.payoutStatus = status;
    }

    const transactions = await Transaction.find(query)
      .populate('packageId', 'title location')
      .populate('bookingId', 'status travelDate')
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await Transaction.countDocuments(query);

    res.json({
      success: true,
      payouts: transactions,
      pagination: {
        total,
        limit: parseInt(limit),
        skip: parseInt(skip),
        hasMore: total > parseInt(skip) + parseInt(limit)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.requestPayout = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = new mongoose.Types.ObjectId(agentId);
    const { paymentMethod, paymentDetails } = req.body;

    const pendingEarnings = await Transaction.aggregate([
      {
        $match: {
          agentId: agentObjectId,
          type: 'EARNING',
          payoutStatus: 'PENDING'
        }
      },
      {
        $group: {
          _id: null,
          totalAmount: { $sum: '$amount' },
          count: { $sum: 1 }
        }
      }
    ]);

    if (!pendingEarnings[0] || pendingEarnings[0].count === 0) {
      return res.status(400).json({
        success: false,
        message: 'No pending earnings to payout'
      });
    }

    const payoutAmount = pendingEarnings[0].totalAmount;

    const payoutTransaction = await Transaction.create({
      agentId,
      type: 'PAYOUT',
      amount: -payoutAmount,
      commissionRate: 0,
      commissionAmount: 0,
      payoutStatus: 'PENDING',
      paymentMethod,
      paymentDetails,
      notes: `Payout request for ${pendingEarnings[0].count} bookings`
    });

    await Transaction.updateMany(
      {
        agentId,
        type: 'EARNING',
        payoutStatus: 'PENDING'
      },
      {
        payoutStatus: 'APPROVED'
      }
    );

    res.status(201).json({
      success: true,
      message: 'Payout request submitted successfully',
      payout: {
        id: payoutTransaction._id,
        amount: payoutAmount,
        bookingCount: pendingEarnings[0].count,
        status: 'PENDING'
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getEarningsReport = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = new mongoose.Types.ObjectId(agentId);
    const { period = 'monthly' } = req.query;

    let groupBy;
    if (period === 'daily') {
      groupBy = {
        $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
      };
    } else if (period === 'weekly') {
      groupBy = {
        $dateToString: { format: '%Y-%U', date: '$createdAt' }
      };
    } else {
      groupBy = {
        $dateToString: { format: '%Y-%m', date: '$createdAt' }
      };
    }

    const earnings = await Transaction.aggregate([
      {
        $match: {
          agentId: agentObjectId,
          type: 'EARNING'
        }
      },
      {
        $group: {
          _id: groupBy,
          earnings: { $sum: '$amount' },
          commission: { $sum: '$commissionAmount' },
          bookings: { $sum: 1 }
        }
      },
      {
        $sort: { _id: -1 }
      }
    ]);

    res.json({
      success: true,
      period,
      report: earnings
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
