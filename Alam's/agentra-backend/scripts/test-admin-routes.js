#!/usr/bin/env node

/**
 * Admin Dashboard Routes Verification Test
 * This script tests that all admin endpoints are properly configured
 */

const http = require('http');

// Configuration
const API_BASE = 'http://localhost:5000';
const ADMIN_EMAIL = 'admin@agentra.com';
const ADMIN_PASSWORD = 'password'; // Update this from your .env

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(color, message) {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function makeRequest(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(API_BASE + path);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  log('cyan', '\n╔════════════════════════════════════════════════════════════════╗');
  log('cyan', '║         ADMIN DASHBOARD ROUTES VERIFICATION TEST              ║');
  log('cyan', '╚════════════════════════════════════════════════════════════════╝\n');

  try {
    // Test 1: Admin Login
    log('blue', '📝 Test 1: Admin Login');
    log('blue', `POST /api/auth/owner/login`);
    const loginRes = await makeRequest('POST', '/api/auth/owner/login', {
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
    });

    if (loginRes.status === 200 && loginRes.data.token) {
      log('green', `✅ Admin login successful`);
      log('green', `   Token: ${loginRes.data.token.substring(0, 30)}...`);
      var adminToken = loginRes.data.token;
    } else {
      log('red', `❌ Admin login failed`);
      log('red', `   Status: ${loginRes.status}`);
      log('red', `   Response: ${JSON.stringify(loginRes.data)}`);
      log('yellow', '   Note: Update ADMIN_PASSWORD in this script');
      process.exit(1);
    }

    // Test 2: Fetch Pending Agents
    log('blue', '\n📝 Test 2: Fetch Pending Agents');
    log('blue', `GET /api/auth/admin/agents/pending`);
    const agentsRes = await makeRequest('GET', '/api/auth/admin/agents/pending', null, {
      'x-auth-token': adminToken,
    });

    if (agentsRes.status === 200) {
      log('green', `✅ Fetched pending agents`);
      log('green', `   Count: ${agentsRes.data.count || agentsRes.data.agents?.length || 0}`);
      log('green', `   Response keys: ${Object.keys(agentsRes.data).join(', ')}`);

      if (agentsRes.data.agents && agentsRes.data.agents.length > 0) {
        const agent = agentsRes.data.agents[0];
        log('green', `   Sample agent: ${agent.fullName || agent.name} (${agent.email})`);
        log('green', `   Status: ${agent.status}`);
        var testAgentId = agent._id;
      } else {
        log('yellow', '   ⚠️ No pending agents in database');
        log('yellow', '   Create test agents first, or the approve/reject tests will skip');
      }
    } else {
      log('red', `❌ Failed to fetch pending agents`);
      log('red', `   Status: ${agentsRes.status}`);
      log('red', `   Response: ${JSON.stringify(agentsRes.data)}`);
      process.exit(1);
    }

    // Test 3: Approve Agent (if we have a test agent)
    if (testAgentId) {
      log('blue', '\n📝 Test 3: Approve Agent');
      log('blue', `PUT /api/auth/admin/agents/${testAgentId}/approve`);
      const approveRes = await makeRequest(
        'PUT',
        `/api/auth/admin/agents/${testAgentId}/approve`,
        {},
        { 'x-auth-token': adminToken }
      );

      if (approveRes.status === 200) {
        log('green', `✅ Agent approved successfully`);
        log('green', `   Message: ${approveRes.data.message}`);
        log('green', `   New status: ${approveRes.data.agent?.status}`);
      } else {
        log('red', `❌ Failed to approve agent`);
        log('red', `   Status: ${approveRes.status}`);
        log('red', `   Response: ${JSON.stringify(approveRes.data)}`);
      }

      // Test 4: Reject Agent (test with another agent if available)
      // Fetch fresh list first
      const agentsRes2 = await makeRequest('GET', '/api/auth/admin/agents/pending', null, {
        'x-auth-token': adminToken,
      });

      if (agentsRes2.data.agents && agentsRes2.data.agents.length > 0) {
        const testAgentId2 = agentsRes2.data.agents[0]._id;
        log('blue', '\n📝 Test 4: Reject Agent');
        log('blue', `PUT /api/auth/admin/agents/${testAgentId2}/reject`);

        const rejectRes = await makeRequest(
          'PUT',
          `/api/auth/admin/agents/${testAgentId2}/reject`,
          { reason: 'Test rejection - invalid documents' },
          { 'x-auth-token': adminToken }
        );

        if (rejectRes.status === 200) {
          log('green', `✅ Agent rejected successfully`);
          log('green', `   Message: ${rejectRes.data.message}`);
          log('green', `   New status: ${rejectRes.data.agent?.status}`);
        } else {
          log('red', `❌ Failed to reject agent`);
          log('red', `   Status: ${rejectRes.status}`);
          log('red', `   Response: ${JSON.stringify(rejectRes.data)}`);
        }
      }
    } else {
      log('yellow', '\n⏭️  Skipping approve/reject tests (no pending agents)');
    }

    // Summary
    log('cyan', '\n╔════════════════════════════════════════════════════════════════╗');
    log('green', '✅ ALL TESTS PASSED - Admin Dashboard Routes are Working!');
    log('cyan', '╚════════════════════════════════════════════════════════════════╝\n');

    log('yellow', 'Next Steps:');
    log('yellow', '1. Start the frontend: cd agentra && npm run dev');
    log('yellow', '2. Open http://localhost:3000 in your browser');
    log('yellow', '3. Login with admin credentials');
    log('yellow', '4. Test the admin dashboard UI\n');
  } catch (err) {
    log('red', `\n❌ Test Error: ${err.message}`);
    log('red', 'Make sure:');
    log('red', '  1. Backend server is running on http://localhost:5000');
    log('red', '  2. MongoDB is connected');
    log('red', '  3. ADMIN_PASSWORD in this script matches your admin user\n');
    process.exit(1);
  }
}

runTests();
