const Booking = require('../models/Booking');
const Package = require('../models/Package');
const Agent = require('../models/Agent');
const User = require('../models/User');
const Complaint = require('../models/Complaint');
const Transaction = require('../models/Transaction');
const { calculateCommission } = require('../utils/commission');
const XLSX = require('xlsx');

const buildDateRange = (startDate, endDate) => {
  if (!startDate && !endDate) return null;

  const range = {};
  if (startDate) {
    range.$gte = new Date(startDate);
  }
  if (endDate) {
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999);
    range.$lte = end;
  }

  return range;
};

const buildCommissionMatch = (query = {}) => {
  const match = { type: 'COMMISSION' };
  if (query.agentId) match.agentId = query.agentId;

  const createdAt = buildDateRange(query.startDate, query.endDate);
  if (createdAt) match.createdAt = createdAt;

  return match;
};

const buildBookingMatch = (query = {}) => {
  const match = {
    paymentStatus: 'PAID',
    status: { $ne: 'CANCELLED' }
  };
  if (query.agentId) match.agentId = query.agentId;

  const createdAt = buildDateRange(query.startDate, query.endDate);
  if (createdAt) match.createdAt = createdAt;

  return match;
};

const buildOwnerCommissionAnalytics = async (query = {}) => {
  const commissionMatch = buildCommissionMatch(query);
  const bookingMatch = buildBookingMatch(query);

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date();
  todayEnd.setHours(23, 59, 59, 999);

  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const monthEnd = new Date();
  monthEnd.setHours(23, 59, 59, 999);

  const yearStart = new Date(new Date().getFullYear(), 0, 1);
  const yearEnd = new Date(new Date().getFullYear(), 11, 31, 23, 59, 59, 999);

  const effectiveCommissionMatch = Object.keys(commissionMatch).length > 1
    ? commissionMatch
    : { type: 'COMMISSION' };

  const summaryMatch = Object.keys(commissionMatch).length > 1
    ? commissionMatch
    : { type: 'COMMISSION' };

  const summaryResult = await Transaction.aggregate([
    { $match: summaryMatch },
    {
      $group: {
        _id: null,
        totalCommissionRevenue: { $sum: '$amount' },
        refundedCommission: {
          $sum: { $cond: [{ $lt: ['$amount', 0] }, { $abs: '$amount' }, 0] }
        }
      }
    }
  ]);

  const todayResult = await Transaction.aggregate([
    { $match: { ...effectiveCommissionMatch, createdAt: { $gte: todayStart, $lte: todayEnd } } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);

  const monthlyResult = await Transaction.aggregate([
    { $match: { ...effectiveCommissionMatch, createdAt: { $gte: monthStart, $lte: monthEnd } } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);

  const yearlyResult = await Transaction.aggregate([
    { $match: { ...effectiveCommissionMatch, createdAt: { $gte: yearStart, $lte: yearEnd } } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);

  const successfulBookings = await Booking.countDocuments(bookingMatch);

  const bookingRevenueResult = await Booking.aggregate([
    { $match: bookingMatch },
    { $group: { _id: null, totalBookingRevenue: { $sum: '$totalAmount' } } }
  ]);

  const totalBookingRevenue = bookingRevenueResult[0]?.totalBookingRevenue || 0;
  const totalCommissionRevenue = summaryResult[0]?.totalCommissionRevenue || 0;
  const totalRefundedCommission = summaryResult[0]?.refundedCommission || 0;

  const trend = await Transaction.aggregate([
    { $match: effectiveCommissionMatch },
    {
      $group: {
        _id: { month: { $substrCP: ['$createdAt', 0, 7] } },
        commissionRevenue: { $sum: '$amount' }
      }
    },
    { $sort: { '_id.month': 1 } },
    { $limit: 12 }
  ]);

  const monthlyReportRows = await Booking.aggregate([
    { $match: bookingMatch },
    {
      $group: {
        _id: { month: { $substrCP: ['$createdAt', 0, 7] } },
        bookingRevenue: { $sum: '$totalAmount' },
        bookingCount: { $sum: 1 }
      }
    },
    { $sort: { '_id.month': 1 } }
  ]);

  const commissionTrend = trend.map((item) => ({
    month: item._id.month,
    commissionRevenue: item.commissionRevenue || 0
  }));

  const monthlyReport = monthlyReportRows.map((item) => ({
    month: item._id.month,
    bookingRevenue: item.bookingRevenue || 0,
    bookingCount: item.bookingCount || 0,
    commissionRevenue: (commissionTrend.find((trendItem) => trendItem.month === item._id.month)?.commissionRevenue || 0)
  }));

  const agentBreakdownAgg = await Transaction.aggregate([
    { $match: effectiveCommissionMatch },
    {
      $group: {
        _id: '$agentId',
        commissionRevenue: { $sum: '$amount' },
        refundedCommission: {
          $sum: { $cond: [{ $lt: ['$amount', 0] }, { $abs: '$amount' }, 0] }
        }
      }
    }
  ]);

  const agentBookingAgg = await Booking.aggregate([
    { $match: bookingMatch },
    {
      $group: {
        _id: '$agentId',
        bookingCount: { $sum: 1 },
        bookingRevenue: { $sum: '$totalAmount' }
      }
    }
  ]);

  const agentBookingMap = new Map(agentBookingAgg.map((item) => [item._id.toString(), item]));
  const agentIds = [...new Set([...agentBreakdownAgg.map((item) => item._id.toString()), ...agentBookingMap.keys()])];

  const agents = await Agent.find({ _id: { $in: agentIds } }).select('fullName businessName').lean();
  const agentMap = new Map(agents.map((item) => [item._id.toString(), item]));

  const agentBreakdown = agentIds.map((agentId) => {
    const commissionEntry = agentBreakdownAgg.find((item) => item._id.toString() === agentId) || null;
    const bookingEntry = agentBookingMap.get(agentId) || null;
    const agent = agentMap.get(agentId);

    return {
      agentId,
      agentName: agent?.businessName || agent?.fullName || 'Unknown Agent',
      commissionRevenue: commissionEntry?.commissionRevenue || 0,
      refundedCommission: commissionEntry?.refundedCommission || 0,
      bookingCount: bookingEntry?.bookingCount || 0,
      bookingRevenue: bookingEntry?.bookingRevenue || 0
    };
  }).sort((a, b) => b.commissionRevenue - a.commissionRevenue);

  const recentTransactions = await Transaction.find(effectiveCommissionMatch)
    .populate('agentId', 'fullName businessName')
    .populate('bookingId', 'totalAmount status paymentStatus commissionPercentage commissionAmount agentEarning createdAt')
    .sort({ createdAt: -1 })
    .limit(20)
    .lean();

  const recentCommissionTransactions = recentTransactions.map((txn) => {
    const booking = txn.bookingId || {};
    const agent = txn.agentId || {};
    const bookingAmount = Number(booking.totalAmount ?? booking.bookingAmount ?? 0);
    const commissionPercentage = Number(booking.commissionPercentage ?? txn.commissionRate ?? 5);
    const commissionAmount = Number(txn.commissionAmount ?? txn.amount ?? (bookingAmount * (commissionPercentage / 100)));
    const agentEarnings = booking.agentEarning !== undefined
      ? Number(booking.agentEarning)
      : Number(bookingAmount - Math.abs(commissionAmount));

    return {
      bookingId: booking._id ? booking._id.toString() : txn.bookingId ? txn.bookingId.toString() : null,
      agentName: agent.businessName || agent.fullName || 'Unknown Agent',
      bookingAmount,
      commissionPercentage,
      commissionAmount,
      agentEarnings,
      bookingStatus: booking.status || 'CONFIRMED',
      paymentStatus: booking.paymentStatus || (txn.amount < 0 ? 'REFUNDED' : 'PAID'),
      createdAt: booking.createdAt || txn.createdAt
    };
  });

  return {
    summary: {
      totalCommissionRevenue,
      todayCommissionRevenue: todayResult[0]?.total || 0,
      monthlyCommissionRevenue: monthlyResult[0]?.total || 0,
      yearlyCommissionRevenue: yearlyResult[0]?.total || 0,
      totalSuccessfulBookings: successfulBookings,
      totalBookingRevenue,
      totalRefundedCommission
    },
    trend: commissionTrend,
    agentBreakdown,
    monthlyReport,
    recentTransactions: recentCommissionTransactions
  };
};

exports.userDashboard = async (req, res) => {
  const bookings = await Booking.find({ userId: req.user.id }).countDocuments();
  res.json({ success: true, totalBookings: bookings });
};

exports.agentDashboard = async (req, res) => {
  const packages = await Package.find({ agentId: req.user.id }).countDocuments();
  const bookings = await Booking.find({ agentId: req.user.id }).countDocuments();
  res.json({ success: true, packages, bookings });
};

exports.getOwnerCommissionAnalytics = async (req, res) => {
  try {
    const analytics = await buildOwnerCommissionAnalytics(req.query);
    res.json({ success: true, ...analytics });
  } catch (error) {
    console.error('❌ Error in getOwnerCommissionAnalytics:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

exports.exportOwnerCommissionReport = async (req, res) => {
  try {
    const analytics = await buildOwnerCommissionAnalytics(req.query);
    const rows = analytics.recentTransactions.map((item) => ({
      'Booking ID': item.bookingId || 'N/A',
      'Agent Name': item.agentName,
      'Booking Amount': item.bookingAmount,
      'Commission Percentage': item.commissionPercentage,
      'Commission Amount': item.commissionAmount,
      'Agent Earnings': item.agentEarnings,
      'Booking Status': item.bookingStatus,
      'Payment Status': item.paymentStatus,
      'Created Date': item.createdAt ? new Date(item.createdAt).toISOString() : 'N/A'
    }));

    const worksheet = XLSX.utils.json_to_sheet(rows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Commission Report');

    const buffer = XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename=commission-report.xlsx');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buffer);
  } catch (error) {
    console.error('❌ Error in exportOwnerCommissionReport:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

exports.ownerDashboard = async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalAgents = await Agent.countDocuments();
    
    // New Agents (Current Month)
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);
    const newAgents = await Agent.countDocuments({ createdAt: { $gte: startOfMonth } });

    const pendingAgents = await Agent.countDocuments({ status: 'PENDING_APPROVAL' });
    const approvedAgents = await Agent.countDocuments({ status: 'APPROVED' });
    const rejectedAgents = await Agent.countDocuments({ status: 'REJECTED' });
    
    const totalBookings = await Booking.countDocuments();
    
    // Pending Refunds
    const pendingRefunds = await Booking.countDocuments({ refundStatus: 'REQUESTED' });
    
    const totalComplaints = await Complaint.countDocuments();

    // Detailed Revenue Breakdown
    const Transaction = require('../models/Transaction');
    
    // 1. Subscription Revenue (100% to Owner)
    const subRevenueResult = await Transaction.aggregate([
      { $match: { type: 'SUBSCRIPTION' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const subscriptionRevenue = subRevenueResult.length > 0 ? subRevenueResult[0].total : 0;

    // 2. Commission Revenue (5% of Booking totalAmount)
    const commissionResult = await Transaction.aggregate([
      { $match: { type: 'COMMISSION' } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const commissionRevenue = commissionResult.length > 0 ? commissionResult[0].total : 0;

    // Total Platform Revenue
    const totalRevenue = subscriptionRevenue + commissionRevenue;

    // Top agents ranked by ACTUAL booking count from Booking collection
    const topAgentsRaw = await Booking.aggregate([
      {
        $group: {
          _id: '$agentId',
          bookingCount: { $sum: 1 },
          totalRevenue: { $sum: '$totalAmount' },
          totalCommission: {
            $sum: { $ifNull: ['$commissionAmount', { $multiply: ['$totalAmount', 0.05] }] }
          },
          agentEarning: {
            $sum: { $ifNull: ['$agentEarning', { $multiply: ['$totalAmount', 0.95] }] }
          }
        }
      },
      { $sort: { bookingCount: -1 } },
      { $limit: 5 },
      {
        $lookup: {
          from: 'agents',
          localField: '_id',
          foreignField: '_id',
          as: 'agentInfo'
        }
      },
      { $unwind: { path: '$agentInfo', preserveNullAndEmpty: false } },
      {
        $project: {
          _id: 1,
          bookingCount: 1,
          totalRevenue: 1,
          totalCommission: 1,
          agentEarning: 1,
          fullName: '$agentInfo.fullName',
          businessName: '$agentInfo.businessName',
          totalPackages: '$agentInfo.totalPackages',
          averageRating: '$agentInfo.averageRating'
        }
      }
    ]);

    // Map to a consistent shape
    const topAgents = topAgentsRaw.map(a => ({
      _id: a._id,
      fullName: a.fullName,
      businessName: a.businessName,
      totalBookings: a.bookingCount,
      totalRevenue: a.totalRevenue,
      totalCommission: a.totalCommission,
      agentEarning: a.agentEarning,
      totalPackages: a.totalPackages || 0,
      averageRating: a.averageRating || 0
    }));

    const commissionAnalytics = await buildOwnerCommissionAnalytics(req.query);

    res.json({
      success: true,
      totalUsers,
      totalAgents,
      newAgents,
      pendingAgents,
      approvedAgents,
      rejectedAgents,
      totalBookings,
      pendingRefunds,
      totalComplaints,
      totalRevenue,
      subscriptionRevenue,
      commissionRevenue,
      topAgents,
      commissionAnalytics
    });
  } catch (error) {
    console.error('❌ Error in ownerDashboard:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};
