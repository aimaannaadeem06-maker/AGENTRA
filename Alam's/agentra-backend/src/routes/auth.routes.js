const express = require('express');
const router = express.Router();

const {
  registerUser,
  loginUser,
  registerAgent,
  loginAgent,
  loginOwner,
  getAgentProfile,
  updateAgentProfile,
  logoutUser,
  getPendingAgents,
  approveAgent,
  rejectAgent,
} = require('../controllers/auth.controller');

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');


// USER
router.post('/user/register', registerUser);
router.post('/user/login', loginUser);
router.post('/user/logout', protect, role('USER'), logoutUser);

// AGENT
router.post('/agent/register', registerAgent);
router.post('/agent/login', loginAgent);

router.get('/agent/profile', protect, role('AGENT'), getAgentProfile);
router.put('/agent/profile', protect, role('AGENT'), updateAgentProfile);

// OWNER
router.post('/owner/login', loginOwner);

// owner ROUTES
router.get('/owner/agents/pending', protect, role('OWNER'), getPendingAgents);
router.put('/owner/agents/:agentId/approve', protect, role('OWNER'), approveAgent);
router.put('/owner/agents/:agentId/reject', protect, role('OWNER'), rejectAgent);

// TEST
router.get('/test', (req, res) => {
  res.json({ success: true, message: 'Auth routes working 🚀' });
});

module.exports = router;
