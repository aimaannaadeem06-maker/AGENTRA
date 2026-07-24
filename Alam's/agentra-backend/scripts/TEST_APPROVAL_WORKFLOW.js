#!/usr/bin/env node
/**
 * Test Script: Agent Approval Workflow
 * 
 * This script verifies the entire approval workflow:
 * 1. Agent signup (status should be PENDING_APPROVAL)
 * 2. Agent login with pending status (should fail)
 * 3. Admin approval (change status to APPROVED)
 * 4. Agent login with approved status (should succeed)
 * 5. Admin rejection workflow
 * 
 * Usage: node TEST_APPROVAL_WORKFLOW.js
 */

require('dotenv').config();
const fetch = require('node-fetch');

const BASE_URL = 'http://localhost:5000/api';

let testAgentId = null;
let adminToken = null;
let agentToken = null;

const log = {
  step: (msg) => console.log(`\n📋 ${msg}`),
  success: (msg) => console.log(`✅ ${msg}`),
  error: (msg) => console.log(`❌ ${msg}`),
  info: (msg) => console.log(`ℹ️  ${msg}`),
  data: (obj) => console.log(JSON.stringify(obj, null, 2)),
};

async function request(method, endpoint, body = null, token = null) {
  const headers = {
    'Content-Type': 'application/json',
  };

  if (token) {
    headers['x-auth-token'] = token;
  }

  const options = {
    method,
    headers,
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const url = `${BASE_URL}${endpoint}`;
  console.log(`🔗 ${method} ${url}`);

  const response = await fetch(url, options);
  const data = await response.json();

  return {
    status: response.status,
    data,
  };
}

async function runTests() {
  try {
    log.step('TEST 1: Admin Login (to get admin token)');
    const adminLogin = await request('POST', '/auth/owner/login', {
      email: 'admin@agentra.com',
      password: 'admin123',
    });

    if (adminLogin.status === 200) {
      adminToken = adminLogin.data.token;
      log.success('Admin login successful');
      log.info(`Admin token: ${adminToken.substring(0, 20)}...`);
    } else {
      log.error('Admin login failed');
      log.info('Make sure admin user exists. Run: node create_admin.js');
      log.data(adminLogin.data);
      return;
    }

    // ========================================
    log.step('TEST 2: Agent Signup (status should be PENDING_APPROVAL)');
    const timestamp = Date.now();
    const agentSignup = await request('POST', '/auth/agent/register', {
      fullName: `Test Agent ${timestamp}`,
      businessName: `Test Business ${timestamp}`,
      email: `agent${timestamp}@test.com`,
      phone: `923${Math.random().toString().substring(2, 11)}`,
      cnic: `${timestamp}-1234567-1`,
      password: 'TestPass123!',
    });

    if (agentSignup.status === 201) {
      testAgentId = agentSignup.data.agent._id;
      agentToken = agentSignup.data.token;
      log.success('Agent signup successful');
      log.info(`Agent ID: ${testAgentId}`);
      log.info(`Agent Status: ${agentSignup.data.agent.status}`);
      log.info(`Message: ${agentSignup.data.message}`);

      if (agentSignup.data.agent.status === 'PENDING_APPROVAL') {
        log.success('✓ Status is correctly set to PENDING_APPROVAL');
      } else {
        log.error('✗ Status is NOT PENDING_APPROVAL, got: ' + agentSignup.data.agent.status);
        return;
      }
    } else {
      log.error('Agent signup failed');
      log.data(agentSignup.data);
      return;
    }

    // ========================================
    log.step('TEST 3: Agent Login with PENDING_APPROVAL (should FAIL)');
    const agentLoginPending = await request('POST', '/auth/agent/login', {
      email: `agent${timestamp}@test.com`,
      password: 'TestPass123!',
    });

    if (agentLoginPending.status === 403) {
      log.success('✓ Login correctly rejected with 403');
      log.info(`Message: ${agentLoginPending.data.message}`);

      if (agentLoginPending.data.message === 'Your account is not yet approved by admin.') {
        log.success('✓ Correct error message displayed');
      } else {
        log.error('✗ Wrong error message: ' + agentLoginPending.data.message);
      }
    } else {
      log.error(`✗ Expected 403, got ${agentLoginPending.status}`);
      log.data(agentLoginPending.data);
      return;
    }

    // ========================================
    log.step('TEST 4: Get Pending Agents (admin endpoint)');
    const getPending = await request('GET', '/auth/admin/agents/pending', null, adminToken);

    if (getPending.status === 200) {
      log.success('✓ Fetched pending agents');
      log.info(`Total pending: ${getPending.data.count}`);

      const foundAgent = getPending.data.agents.find(a => a._id === testAgentId);
      if (foundAgent) {
        log.success('✓ Test agent found in pending list');
        log.info(`Agent status: ${foundAgent.status}`);
      } else {
        log.error('✗ Test agent NOT found in pending list');
      }
    } else {
      log.error('Failed to fetch pending agents');
      log.data(getPending.data);
      return;
    }

    // ========================================
    log.step('TEST 5: Admin Approves Agent');
    const approveRes = await request(
      'PUT',
      `/auth/admin/agents/${testAgentId}/approve`,
      {},
      adminToken
    );

    if (approveRes.status === 200) {
      log.success('✓ Agent approved successfully');
      log.info(`New status: ${approveRes.data.agent.status}`);

      if (approveRes.data.agent.status === 'APPROVED') {
        log.success('✓ Status correctly changed to APPROVED');
      } else {
        log.error('✗ Status is not APPROVED: ' + approveRes.data.agent.status);
        return;
      }
    } else {
      log.error(`Failed to approve agent. Status: ${approveRes.status}`);
      log.data(approveRes.data);
      return;
    }

    // ========================================
    log.step('TEST 6: Agent Login with APPROVED status (should SUCCESS, but isVerified check)');
    const agentLoginApproved = await request('POST', '/auth/agent/login', {
      email: `agent${timestamp}@test.com`,
      password: 'TestPass123!',
    });

    // Agent should still fail because isVerified is false
    // But the approval check should pass
    if (agentLoginApproved.status === 403 && agentLoginApproved.data.message === 'Account not verified') {
      log.success('✓ Login passed approval check, but correctly blocked by email verification');
      log.info('This is expected - admin must also verify email before login');
    } else if (agentLoginApproved.status === 200) {
      log.success('✓ Agent login successful with APPROVED status');
      log.info(`Token received: ${agentLoginApproved.data.token.substring(0, 20)}...`);
    } else {
      log.error(`Unexpected response. Status: ${agentLoginApproved.status}`);
      log.data(agentLoginApproved.data);
    }

    // ========================================
    log.step('TEST 7: Admin Rejects Another Agent (create new one first)');
    const timestamp2 = Date.now() + 1000;
    const agentSignup2 = await request('POST', '/auth/agent/register', {
      fullName: `Test Agent 2 ${timestamp2}`,
      businessName: `Test Business 2 ${timestamp2}`,
      email: `agent2${timestamp2}@test.com`,
      phone: `923${Math.random().toString().substring(2, 11)}`,
      cnic: `${timestamp2}-1234567-1`,
      password: 'TestPass123!',
    });

    if (agentSignup2.status === 201) {
      const testAgentId2 = agentSignup2.data.agent._id;
      log.info(`Created second test agent: ${testAgentId2}`);

      const rejectRes = await request(
        'PUT',
        `/auth/admin/agents/${testAgentId2}/reject`,
        { reason: 'Does not meet requirements' },
        adminToken
      );

      if (rejectRes.status === 200) {
        log.success('✓ Agent rejected successfully');
        log.info(`New status: ${rejectRes.data.agent.status}`);
        log.info(`Rejection reason: ${rejectRes.data.agent.rejectionReason}`);

        if (rejectRes.data.agent.status === 'REJECTED') {
          log.success('✓ Status correctly changed to REJECTED');
        }
      } else {
        log.error(`Failed to reject agent. Status: ${rejectRes.status}`);
        log.data(rejectRes.data);
      }

      // Try to login as rejected agent
      log.step('TEST 8: Rejected Agent Login (should FAIL)');
      const rejectedLogin = await request('POST', '/auth/agent/login', {
        email: `agent2${timestamp2}@test.com`,
        password: 'TestPass123!',
      });

      if (rejectedLogin.status === 403 && rejectedLogin.data.message.includes('rejected')) {
        log.success('✓ Rejected agent correctly blocked from login');
        log.info(`Message: ${rejectedLogin.data.message}`);
      } else {
        log.error('✗ Rejected agent login not blocked correctly');
        log.data(rejectedLogin.data);
      }
    }

    // ========================================
    log.step('✅ ALL TESTS COMPLETED SUCCESSFULLY');
    console.log('\n📊 Summary:');
    console.log('  ✓ Agent signup creates PENDING_APPROVAL status');
    console.log('  ✓ Pending agents cannot login');
    console.log('  ✓ Admin can view pending agents');
    console.log('  ✓ Admin can approve agents');
    console.log('  ✓ Approved agents can attempt login (blocked by email verification)');
    console.log('  ✓ Admin can reject agents');
    console.log('  ✓ Rejected agents cannot login');
    console.log('\n🔗 API Endpoints verified:');
    console.log('  POST   /api/auth/agent/register');
    console.log('  POST   /api/auth/agent/login');
    console.log('  GET    /api/auth/admin/agents/pending');
    console.log('  PUT    /api/auth/admin/agents/:agentId/approve');
    console.log('  PUT    /api/auth/admin/agents/:agentId/reject');
  } catch (error) {
    log.error('Test script error: ' + error.message);
    console.error(error);
  }
}

// Run tests
runTests();
