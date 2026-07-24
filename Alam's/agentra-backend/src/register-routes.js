const authRoutes = require('./routes/auth.routes');
const packageRoutes = require('./routes/package.routes');
const bookingRoutes = require('./routes/booking.routes');
const userRoutes = require('./routes/user.routes');
const agentRoutes = require('./routes/agent.routes');
const dashboardRoutes = require('./routes/dashboard.routes');
const analyticsRoutes = require('./routes/analytics.routes');
const subscriptionRoutes = require('./routes/subscription.routes');
const paymentRoutes = require('./routes/payment.routes');
const earningsRoutes = require('./routes/earnings.routes');
const searchRoutes = require('./routes/search.routes');
const chatbotRoutes = require('./routes/chatbot.routes');
const promotionRoutes = require('./routes/promotion.routes');
const refundRoutes = require('./routes/refund.routes');
const savedRoutes = require('./routes/saved.routes');
const ownerRoutes = require('./routes/owner.routes');
const complaintsRoutes = require('./routes/complaints.routes');
const logsRoutes = require('./routes/logs.routes');
const notificationRoutes = require('./routes/notification.routes');
const uploadRoutes = require('./routes/upload');
const walletRoutes = require('./routes/wallet.routes');

const mountAtPrefix = (app, prefix) => {
  app.use(`${prefix}/auth`, authRoutes);
  app.use(`${prefix}/packages`, packageRoutes);
  app.use(`${prefix}/bookings`, bookingRoutes);
  app.use(`${prefix}/users`, userRoutes);
  app.use(`${prefix}/agents`, agentRoutes);
  app.use(`${prefix}/dashboard`, dashboardRoutes);
  app.use(`${prefix}/analytics`, analyticsRoutes);
  app.use(`${prefix}/subscription`, subscriptionRoutes);
  app.use(`${prefix}/payments`, paymentRoutes);
  app.use(`${prefix}/earnings`, earningsRoutes);
  app.use(`${prefix}/search`, searchRoutes);
  app.use(`${prefix}/chatbot`, chatbotRoutes);
  app.use(`${prefix}/promotion`, promotionRoutes);
  app.use(`${prefix}/refund`, refundRoutes);
  app.use(`${prefix}/saved`, savedRoutes);
  app.use(`${prefix}/owner`, ownerRoutes);
  app.use(`${prefix}/complaints`, complaintsRoutes);
  app.use(`${prefix}/logs`, logsRoutes);
  app.use(`${prefix}/notifications`, notificationRoutes);
  app.use(`${prefix}/upload`, uploadRoutes);
  app.use(`${prefix}/wallet`, walletRoutes);
};

const registerRoutes = (app) => {
  // Canonical API prefix.
  mountAtPrefix(app, '/api');

  // Compatibility for clients that accidentally build /api/api/... URLs.
  mountAtPrefix(app, '/api/api');

  // Compatibility for legacy owner paths expected by existing clients.
  app.use('/api/auth/owner', ownerRoutes);
  app.use('/api/api/auth/owner', ownerRoutes);
};

module.exports = { registerRoutes };
