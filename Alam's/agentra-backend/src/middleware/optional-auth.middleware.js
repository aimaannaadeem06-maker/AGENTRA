const jwt = require('jsonwebtoken');

const optionalAuth = (req, res, next) => {
  const token = req.header('x-auth-token');
  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
  } catch (err) {
    // Optional auth should not block public usage.
    req.user = undefined;
  }

  return next();
};

module.exports = optionalAuth;
