const express = require('express');
const router = express.Router();

const protect = require('../middleware/auth.middleware');
const role = require('../middleware/role.middleware');
const logsController = require('../controllers/logs.controller');

// =============== GET SYSTEM LOGS ===============
router.get('/', protect, role('OWNER'), logsController.getSystemLogs);

module.exports = router;
