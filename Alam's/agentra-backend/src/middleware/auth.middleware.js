const jwt = require('jsonwebtoken');

const protect = (req, res, next) => {
  let token;

  // Check for token in header
  if (req.header('Authorization') && req.header('Authorization').startsWith('Bearer ')) {
    token = req.header('Authorization').replace('Bearer ', '');
  } else if (req.header('x-auth-token')) {
    token = req.header('x-auth-token');
  }

  if (!token) return res.status(401).json({ success: false, msg: 'No token, authorization denied' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { id, role }
    next();
  } catch (err) {
    return res.status(401).json({ success: false, msg: 'Token is not valid' });
  }
};

module.exports = protect;
