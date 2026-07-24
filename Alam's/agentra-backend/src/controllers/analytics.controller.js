const Analytics = require('../models/Analytics');
const Package = require('../models/Package');
const Booking = require('../models/Booking');
const PDFDocument = require('pdfkit');
const moment = require('moment');
const mongoose = require('mongoose');

const resolvePackageId = (req) => req.params.packageId || req.params.id;
const toObjectId = (id) => new mongoose.Types.ObjectId(id);

exports.getPackageAnalytics = async (req, res) => {
  try {
    const packageId = resolvePackageId(req);
    const { startDate, endDate } = req.query;

    const analytics = await Analytics.findOne({ packageId });

    if (!analytics) {
      return res.status(404).json({
        success: false,
        message: 'Analytics not found for this package'
      });
    }

    let query = { packageId };
    if (startDate && endDate) {
      query.createdAt = { $gte: new Date(startDate), $lte: new Date(endDate) };
    }

    const bookings = await Booking.countDocuments(query);

    res.json({
      success: true,
      analytics: {
        views: analytics.views,
        clicks: analytics.clicks,
        bookings: bookings,
        conversionRate: analytics.conversionRate,
        revenue: analytics.revenue,
        date: analytics.date
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.trackPackageView = async (req, res) => {
  try {
    const packageId = resolvePackageId(req);

    let analytics = await Analytics.findOne({ packageId });

    if (!analytics) {
      const pkg = await Package.findById(packageId);
      if (!pkg) {
        return res.status(404).json({
          success: false,
          message: 'Package not found'
        });
      }

      analytics = await Analytics.create({
        packageId,
        agentId: pkg.agentId,
        views: 1
      });
    } else {
      analytics.views += 1;
      await analytics.save();
    }

    res.json({
      success: true,
      views: analytics.views
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.trackPackageClick = async (req, res) => {
  try {
    const packageId = resolvePackageId(req);

    let analytics = await Analytics.findOne({ packageId });

    if (!analytics) {
      const pkg = await Package.findById(packageId);
      if (!pkg) {
        return res.status(404).json({
          success: false,
          message: 'Package not found'
        });
      }

      analytics = await Analytics.create({
        packageId,
        agentId: pkg.agentId,
        clicks: 1
      });
    } else {
      analytics.clicks += 1;
      if (analytics.views > 0) {
        analytics.conversionRate = (analytics.bookings / analytics.views) * 100;
      }
      await analytics.save();
    }

    res.json({
      success: true,
      clicks: analytics.clicks
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getAgentAnalytics = async (req, res) => {
  try {
    const agentId = req.user.id;
    const { startDate, endDate } = req.query;

    const query = { agentId };

    // Build booking date filter for revenue/booking counts
    const bookingDateFilter = {};
    if (startDate) bookingDateFilter.$gte = new Date(startDate);
    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      bookingDateFilter.$lte = end;
    }

    const analyticsList = await Analytics.find(query);

    // For each package, compute real booking count and revenue within date range
    const agentObjectId = toObjectId(agentId);
    const bookingMatch = { agentId: agentObjectId, paymentStatus: 'PAID' };
    if (startDate || endDate) {
      bookingMatch.createdAt = bookingDateFilter;
    }

    const bookingAgg = await Booking.aggregate([
      { $match: bookingMatch },
      {
        $group: {
          _id: '$packageId',
          count: { $sum: 1 },
          revenue: { $sum: '$totalAmount' }
        }
      }
    ]);

    const bookingMap = {};
    for (const b of bookingAgg) {
      bookingMap[b._id.toString()] = { count: b.count, revenue: b.revenue };
    }

    const totalViews = analyticsList.reduce((sum, a) => sum + a.views, 0);
    const totalClicks = analyticsList.reduce((sum, a) => sum + a.clicks, 0);
    const totalBookings = bookingAgg.reduce((sum, b) => sum + b.count, 0);
    const totalRevenue = bookingAgg.reduce((sum, b) => sum + b.revenue, 0);

    const packageAnalytics = await Promise.all(
      analyticsList.map(async (a) => {
        const pkg = await Package.findById(a.packageId).select('title price location');
        const pkgId = a.packageId.toString();
        const bData = bookingMap[pkgId] || { count: 0, revenue: 0 };
        const cvr = a.views > 0 ? ((bData.count / a.views) * 100).toFixed(1) : '0.0';
        return {
          package: pkg,
          analytics: {
            views: a.views,
            clicks: a.clicks,
            bookings: bData.count,
            revenue: bData.revenue,
            conversionRate: parseFloat(cvr),
            clickRate: a.views > 0 ? ((a.clicks / a.views) * 100).toFixed(1) : '0.0',
          }
        };
      })
    );

    res.json({
      success: true,
      overview: {
        totalViews,
        totalClicks,
        totalBookings,
        totalRevenue,
        averageConversionRate: totalViews > 0 ? (totalBookings / totalViews) * 100 : 0
      },
      packages: packageAnalytics
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.generatePDFReport = async (req, res) => {
  try {
    const packageId = resolvePackageId(req);

    const analytics = await Analytics.findOne({ packageId })
      .populate('packageId')
      .populate('agentId', 'fullName businessName email');

    if (!analytics) {
      return res.status(404).json({
        success: false,
        message: 'Analytics not found'
      });
    }

    const doc = new PDFDocument();
    const filename = `analytics-report-${packageId}-${Date.now()}.pdf`;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    doc.pipe(res);

    doc.fontSize(20).text('Package Analytics Report', { align: 'center' });
    doc.moveDown();
    doc.fontSize(12).text(`Generated: ${moment().format('YYYY-MM-DD HH:mm:ss')}`);
    doc.moveDown();

    doc.fontSize(16).text('Package Details', { underline: true });
    doc.fontSize(12);
    doc.text(`Title: ${analytics.packageId?.title || 'N/A'}`);
    doc.text(`Location: ${analytics.packageId?.location || 'N/A'}`);
    doc.text(`Price: $${analytics.packageId?.price || 0}`);
    doc.moveDown();

    doc.fontSize(16).text('Agent Details', { underline: true });
    doc.fontSize(12);
    doc.text(`Name: ${analytics.agentId?.fullName || 'N/A'}`);
    doc.text(`Business: ${analytics.agentId?.businessName || 'N/A'}`);
    doc.text(`Email: ${analytics.agentId?.email || 'N/A'}`);
    doc.moveDown();

    doc.fontSize(16).text('Performance Metrics', { underline: true });
    doc.fontSize(12);
    doc.text(`Total Views: ${analytics.views}`);
    doc.text(`Total Clicks: ${analytics.clicks}`);
    doc.text(`Total Bookings: ${analytics.bookings}`);
    doc.text(`Conversion Rate: ${analytics.conversionRate.toFixed(2)}%`);
    doc.text(`Total Revenue: $${analytics.revenue}`);
    doc.moveDown();

    const daysSinceCreation = Math.floor((Date.now() - new Date(analytics.createdAt)) / (1000 * 60 * 60 * 24));
    doc.fontSize(16).text('Daily Averages', { underline: true });
    doc.fontSize(12);
    if (daysSinceCreation > 0) {
      doc.text(`Average Views/Day: ${(analytics.views / daysSinceCreation).toFixed(2)}`);
      doc.text(`Average Clicks/Day: ${(analytics.clicks / daysSinceCreation).toFixed(2)}`);
      doc.text(`Average Bookings/Day: ${(analytics.bookings / daysSinceCreation).toFixed(2)}`);
    }

    doc.end();
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

exports.getDashboardStats = async (req, res) => {
  try {
    const agentId = req.user.id;
    const agentObjectId = toObjectId(agentId);

    const totalPackages = await Package.countDocuments({ agentId });
    const totalBookings = await Booking.countDocuments({ agentId });

    const analytics = await Analytics.find({ agentId });
    const totalViews = analytics.reduce((sum, a) => sum + a.views, 0);
    const totalClicks = analytics.reduce((sum, a) => sum + a.clicks, 0);

    const revenue = await Booking.aggregate([
      { $match: { agentId: agentObjectId, paymentStatus: 'PAID' } },
      { $group: { _id: null, total: { $sum: '$totalAmount' } } }
    ]);

    const conversionRate = totalViews > 0 ? (totalBookings / totalViews) * 100 : 0;

    res.json({
      success: true,
      stats: {
        totalPackages,
        totalBookings,
        totalViews,
        totalClicks,
        totalRevenue: revenue[0]?.total || 0,
        conversionRate: conversionRate.toFixed(2)
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
