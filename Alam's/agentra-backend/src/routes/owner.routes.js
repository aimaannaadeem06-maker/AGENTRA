const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const ownerController = require('../controllers/owner.controller');

// ================= AGENTS =================
router.get('/agents', protect, role('OWNER'), ownerController.getAgents);
router.put('/agents/:id/verify', protect, role('OWNER'), ownerController.verifyAgent);

// Send a 30-day notice before blocking or deleting
router.post('/agents/:id/notice', protect, role('OWNER'), ownerController.sendNotice);

// Block / unblock
router.put('/agents/:id/block', protect, role('OWNER'), ownerController.blockAgent);
router.put('/agents/:id/unblock', protect, role('OWNER'), ownerController.unblockAgent);

// Permanently delete
router.delete('/agents/:id', protect, role('OWNER'), ownerController.deleteAgent);

// Legacy reject (kept for backward compat)
router.delete('/agents/:id/reject', protect, role('OWNER'), ownerController.rejectAgent);

// Standardized Approval/Rejection Aliases (Matches UI expectations)
router.patch('/travel-agents/:id/approve', protect, role('OWNER'), ownerController.verifyAgent);
router.patch('/travel-agents/:id/reject', protect, role('OWNER'), ownerController.rejectAgent);

// ================= COMPLAINTS =================
router.get('/complaints', protect, role('OWNER'), ownerController.getComplaints);
router.put('/complaints/:id/respond', protect, role('OWNER'), ownerController.respondComplaint);

// ================= DASHBOARD =================
router.get('/dashboard', protect, role('OWNER'), ownerController.getDashboardStats);

module.exports = router;
