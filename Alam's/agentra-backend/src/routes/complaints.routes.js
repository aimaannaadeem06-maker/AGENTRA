const express = require('express');
const router  = express.Router();
const protect = require('../middleware/auth.middleware');
const role    = require('../middleware/role.middleware');
const ctrl    = require('../controllers/complaints.controller');

// ── USER ──────────────────────────────────────────────────────────────────────
router.post('/',     protect, role('USER'),  ctrl.submitComplaint);   // submit
router.get('/my',    protect, role('USER'),  ctrl.getMyComplaints);   // my list

// ── owner / OWNER ─────────────────────────────────────────────────────────────
router.get('/',              protect, role('OWNER'), ctrl.getAllComplaints);
router.put('/:id',           protect, role('OWNER'), ctrl.updateComplaintStatus);  // resolve directly
router.put('/:id/forward',   protect, role('OWNER'), ctrl.forwardToAgent);         // forward to agent

// ── AGENT ─────────────────────────────────────────────────────────────────────
router.get('/agent-received',   protect, role('AGENT'), ctrl.getAgentComplaints);
router.put('/:id/resolve',      protect, role('AGENT'), ctrl.agentResolveComplaint);

module.exports = router;
