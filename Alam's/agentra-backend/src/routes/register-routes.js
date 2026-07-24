const authRoutes = require("../routes/auth.routes");
const ownerRoutes = require("../routes/owner.routes");

const registerRoutes = (app) => {
  app.use("/api/auth", authRoutes);

  // 🔥 REQUIRED
  app.use("/api/owner", ownerRoutes);
};

module.exports = { registerRoutes };
