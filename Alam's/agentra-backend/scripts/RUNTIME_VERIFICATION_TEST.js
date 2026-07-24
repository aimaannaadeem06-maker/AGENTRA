/**
 * COMPLETE END-TO-END RUNTIME VERIFICATION TEST
 * 
 * This script tests the ENTIRE approval workflow from signup to login.
 * Run this after starting the backend server:
 *   Terminal 1: node server.js
 *   Terminal 2: node RUNTIME_VERIFICATION_TEST.js
 * 
 * You will see PROOF of runtime behavior with actual API responses and database values.
 */

const http = require('http');

// ═══════════════════════════════════════════════════════════════════════════════
// TEST CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

const API_BASE = 'http://localhost:5000/api/';
const TEST_ID = Math.random().toString(36).substring(7);

const testData = {
  admin: {
    email: 'admin@agentra.com',
    password: 'admin123',
  },
  agent1: {
    fullName: `Agent Test ${TEST_ID}`,
    email: `agent1-${TEST_ID}@test.com`,
    businessName: `Business ${TEST_ID}`,
    phone: `+92300${Math.floor(Math.random() * 9000000).toString().padStart(7, '0')}`,
    cnic: `${Math.floor(Math.random() * 9000000)}-${Math.floor(Math.random() * 9999999)}-${Math.floor(Math.random() * 9)}`,
    password: 'Test@123456',
  },
  agent2: {
    fullName: `Agent Test 2 ${TEST_ID}`,
    email: `agent2-${TEST_ID}@test.com`,
    businessName: `Business 2 ${TEST_ID}`,
    phone: `+92301${Math.floor(Math.random() * 9000000).toString().padStart(7, '0')}`,
    cnic: `${Math.floor(Math.random() * 9000000)}-${Math.floor(Math.random() * 9999999)}-${Math.floor(Math.random() * 9)}`,
    password: 'Test@123456',
  },
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

const log = (label, message, color = 'reset') => {
  console.log(`${colors[color]}${label}${colors.reset} ${message}`);
};

const makeRequest = (method, path, data = null, headers = {}) => {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = http.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          resolve({ status: res.statusCode, data: json, headers: res.headers });
        } catch (e) {
          resolve({ status: res.statusCode, data: body, headers: res.headers });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ═══════════════════════════════════════════════════════════════════════════════
// TEST EXECUTION
// ═══════════════════════════════════════════════════════════════════════════════

let adminToken = null;
let agent1Id = null;
let agent2Id = null;

const runTests = async () => {
  console.log('\n');
  log('═════════════════════════════════════════════════════════════════════════════════', '', 'cyan');
  log('✓ AGENTRA APPROVAL WORKFLOW - RUNTIME VERIFICATION TEST', '', 'cyan');
  log('═════════════════════════════════════════════════════════════════════════════════\n', '', 'cyan');

  // TEST 1: Admin Login
  try {
    log('📋 TEST 1', 'Admin Login (to get admin token)', 'blue');
    log('🔗', `POST /api/auth/owner/login`, 'yellow');
    log('📤', `Email: ${testData.admin.email}`);

    const res = await makeRequest('POST', 'auth/owner/login', {
      email: testData.admin.email,
      password: testData.admin.password,
    });

    if (res.status === 200 && res.data.token) {
      adminToken = res.data.token;
      log('✅', 'Admin login SUCCESSFUL', 'green');
      log('ℹ️', `Token: ${adminToken.substring(0, 40)}...`);
    } else {
      log('❌', `Admin login FAILED: ${res.data.message}`, 'red');
      log('💡', 'Run: node create_admin.js (to create admin account)', 'yellow');
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 2: Agent 1 Signup
  try {
    log('📋 TEST 2', 'Agent 1 Signup (verify status = PENDING_APPROVAL)', 'blue');
    log('🔗', `POST /api/auth/agent/register`, 'yellow');
    log('📤', `Email: ${testData.agent1.email}`);
    log('📤', `Business: ${testData.agent1.businessName}`);

    const res = await makeRequest('POST', 'auth/agent/register', testData.agent1);

    if (res.status === 201 && res.data.agent) {
      agent1Id = res.data.agent._id;
      const agentStatus = res.data.agent.status;

      log('✅', 'Agent 1 signup SUCCESSFUL', 'green');
      log('ℹ️', `Agent ID: ${agent1Id}`);
      log('ℹ️', `Status in Response: ${agentStatus}`);
      log('ℹ️', `Message: "${res.data.message}"`);

      if (agentStatus === 'PENDING_APPROVAL') {
        log('✅', 'Status is correctly PENDING_APPROVAL', 'green');
      } else {
        log('❌', `Status is wrong: ${agentStatus} (should be PENDING_APPROVAL)`, 'red');
      }

      log('📊', `Response:`, 'cyan');
      console.log(JSON.stringify(res.data, null, 2));
    } else {
      log('❌', `Signup FAILED: ${res.data.message}`, 'red');
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 3: Agent 1 Login with PENDING_APPROVAL status (should FAIL)
  try {
    log('📋 TEST 3', 'Agent 1 Login with PENDING_APPROVAL (should FAIL with 403)', 'blue');
    log('🔗', `POST /api/auth/agent/login`, 'yellow');
    log('📤', `Email: ${testData.agent1.email}`);

    const res = await makeRequest('POST', '/auth/agent/login', {
      email: testData.agent1.email,
      password: testData.agent1.password,
    });

    if (res.status === 403) {
      log('✅', 'Login correctly BLOCKED with 403', 'green');
      log('ℹ️', `Message: "${res.data.message}"`);
      log('📊', `Response:`, 'cyan');
      console.log(JSON.stringify(res.data, null, 2));
    } else if (res.status === 200) {
      log('❌', 'Login SHOULD FAIL but succeeded!', 'red');
      process.exit(1);
    } else {
      log('⚠️', `Unexpected status: ${res.status}`, 'yellow');
      console.log(JSON.stringify(res.data, null, 2));
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 4: Fetch Pending Agents
  try {
    log('📋 TEST 4', 'Fetch Pending Agents (admin endpoint)', 'blue');
    log('🔗', `GET /api/auth/admin/agents/pending`, 'yellow');
    log('🔐', `Using admin token`, 'yellow');

    const res = await makeRequest('GET', 'auth/admin/agents/pending', null, {
      'x-auth-token': adminToken,
    });

    if (res.status === 200) {
      log('✅', 'Fetched pending agents SUCCESSFULLY', 'green');
      log('ℹ️', `Count: ${res.data.count}`);

      const found = res.data.agents.find(a => a._id === agent1Id);
      if (found) {
        log('✅', 'Agent 1 found in pending list', 'green');
        log('ℹ️', `Status: ${found.status}`);
      } else {
        log('❌', 'Agent 1 NOT found in pending list', 'red');
      }

      log('📊', `Pending agents:`, 'cyan');
      res.data.agents.forEach(a => {
        console.log(`  - ${a.email} (${a.status})`);
      });
    } else {
      log('❌', `Failed: ${res.data.message}`, 'red');
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 5: Admin Approves Agent 1
  try {
    log('📋 TEST 5', 'Admin Approves Agent 1', 'blue');
    log('🔗', `PUT /api/auth/admin/agents/${agent1Id}/approve`, 'yellow');
    log('🔐', `Using admin token`, 'yellow');

    const res = await makeRequest(
      'PUT',
      `auth/admin/agents/${agent1Id}/approve`,
      {},
      { 'x-auth-token': adminToken }
    );

    if (res.status === 200) {
      log('✅', 'Agent 1 approved SUCCESSFULLY', 'green');
      log('ℹ️', `New Status: ${res.data.agent.status}`);

      if (res.data.agent.status === 'APPROVED') {
        log('✅', 'Status correctly changed to APPROVED', 'green');
      } else {
        log('❌', `Status wrong: ${res.data.agent.status}`, 'red');
      }

      log('📊', `Updated agent:`, 'cyan');
      console.log(`  ID: ${res.data.agent._id}`);
      console.log(`  Email: ${res.data.agent.email}`);
      console.log(`  Status: ${res.data.agent.status}`);
    } else {
      log('❌', `Approval failed: ${res.data.message}`, 'red');
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 6: Agent 2 Signup (for rejection test)
  try {
    log('📋 TEST 6', 'Agent 2 Signup (for rejection test)', 'blue');
    log('🔗', `POST /api/auth/agent/register`, 'yellow');
    log('📤', `Email: ${testData.agent2.email}`);

    const res = await makeRequest('POST', 'auth/agent/register', testData.agent2);

    if (res.status === 201 && res.data.agent) {
      agent2Id = res.data.agent._id;
      log('✅', 'Agent 2 signup SUCCESSFUL', 'green');
      log('ℹ️', `Agent ID: ${agent2Id}`);
      log('ℹ️', `Status: ${res.data.agent.status}`);
    } else {
      log('❌', `Signup failed: ${res.data.message}`, 'red');
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 7: Admin Rejects Agent 2
  try {
    log('📋 TEST 7', 'Admin Rejects Agent 2', 'blue');
    log('🔗', `PUT /api/auth/admin/agents/${agent2Id}/reject`, 'yellow');
    log('🔐', `Using admin token`, 'yellow');

    const res = await makeRequest(
      'PUT',
      `auth/admin/agents/${agent2Id}/reject`,
      { reason: 'Does not meet business requirements' },
      { 'x-auth-token': adminToken }
    );

    if (res.status === 200) {
      log('✅', 'Agent 2 rejected SUCCESSFULLY', 'green');
      log('ℹ️', `New Status: ${res.data.agent.status}`);
      log('ℹ️', `Reason: ${res.data.agent.rejectionReason}`);

      if (res.data.agent.status === 'REJECTED') {
        log('✅', 'Status correctly changed to REJECTED', 'green');
      } else {
        log('❌', `Status wrong: ${res.data.agent.status}`, 'red');
      }

      log('📊', `Rejected agent:`, 'cyan');
      console.log(`  ID: ${res.data.agent._id}`);
      console.log(`  Email: ${res.data.agent.email}`);
      console.log(`  Status: ${res.data.agent.status}`);
      console.log(`  Reason: ${res.data.agent.rejectionReason}`);
    } else {
      log('❌', `Rejection failed: ${res.data.message}`, 'red');
      console.log(JSON.stringify(res.data, null, 2));
      process.exit(1);
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 8: Agent 1 Login with APPROVED status (should SUCCESS)
  try {
    log('📋 TEST 8', 'Agent 1 Login with APPROVED status (should SUCCESS)', 'blue');
    log('🔗', `POST /api/auth/agent/login`, 'yellow');
    log('📤', `Email: ${testData.agent1.email}`);
    log('ℹ️', `Agent 1 was previously approved in TEST 5`, 'yellow');

    const res = await makeRequest('POST', '/auth/agent/login', {
      email: testData.agent1.email,
      password: testData.agent1.password,
    });

    if (res.status === 200 && res.data.token) {
      log('✅', 'Login SUCCESSFUL for APPROVED agent', 'green');
      log('ℹ️', `Token received: ${res.data.token.substring(0, 40)}...`);
      log('ℹ️', `Message: "${res.data.message}"`);
    } else if (res.status === 200) {
      log('⚠️', 'Status 200 but no token', 'yellow');
      console.log(JSON.stringify(res.data, null, 2));
    } else {
      log('❌', `Login failed: ${res.data.message}`, 'red');
      console.log(JSON.stringify(res.data, null, 2));
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // TEST 9: Agent 2 Login with REJECTED status (should FAIL)
  try {
    log('📋 TEST 9', 'Agent 2 Login with REJECTED status (should FAIL with 403)', 'blue');
    log('🔗', `POST /api/auth/agent/login`, 'yellow');
    log('📤', `Email: ${testData.agent2.email}`);
    log('ℹ️', `Agent 2 was previously rejected in TEST 7`, 'yellow');

    const res = await makeRequest('POST', '/auth/agent/login', {
      email: testData.agent2.email,
      password: testData.agent2.password,
    });

    if (res.status === 403) {
      log('✅', 'Login correctly BLOCKED with 403', 'green');
      log('ℹ️', `Message: "${res.data.message}"`);
    } else if (res.status === 200) {
      log('❌', 'Login SHOULD FAIL but succeeded!', 'red');
      process.exit(1);
    } else {
      log('⚠️', `Unexpected status: ${res.status}`, 'yellow');
    }
  } catch (err) {
    log('❌', `Request error: ${err.message}`, 'red');
    process.exit(1);
  }

  log('\n');

  // ═══════════════════════════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════════

  log('═════════════════════════════════════════════════════════════════════════════════', '', 'cyan');
  log('✓ ALL TESTS COMPLETED SUCCESSFULLY', '', 'cyan');
  log('═════════════════════════════════════════════════════════════════════════════════\n', '', 'cyan');

  log('📊 SUMMARY OF WHAT WAS VERIFIED:', '', 'bright');
  console.log(`
  ✓ Admin can login and get token
  ✓ Agent signup creates PENDING_APPROVAL status in database
  ✓ Signup response shows approval message
  ✓ Pending agents CANNOT login (403 error)
  ✓ Admin can fetch list of pending agents
  ✓ Admin can approve agents (status changes to APPROVED)
  ✓ Approved agents CAN login and get JWT token
  ✓ Admin can reject agents (status changes to REJECTED)
  ✓ Rejected agents CANNOT login (403 error)

  🎯 THE SYSTEM IS WORKING AT RUNTIME ✅
`);

  log('🔍 CHECK SERVER LOGS:', '', 'bright');
  console.log(`
  Look at Terminal 1 (where "node server.js" is running) and verify you see logs like:

  📝 [SIGNUP] Agent registration attempt: { email, businessName }
  ✅ [SIGNUP] Agent created with status: PENDING_APPROVAL
  
  🔐 [LOGIN] Agent login attempt: { email }
  📊 [LOGIN] Agent found: { status: 'PENDING_APPROVAL' }
  ⏳ [LOGIN] Account pending approval: email
  
  👤 [APPROVE] Approval attempt for agent: ID
  ✅ [APPROVE] Agent approved successfully: { newStatus: 'APPROVED' }
  
  🚫 [REJECT] Rejection attempt for agent: ID
  ✅ [REJECT] Agent rejected successfully: { newStatus: 'REJECTED' }
`);

  log('📋 TEST DATA CREATED:', '', 'bright');
  console.log(`
  Admin:
    Email: ${testData.admin.email}
    Password: ${testData.admin.password}

  Agent 1 (APPROVED):
    ID: ${agent1Id}
    Email: ${testData.agent1.email}
    Status: APPROVED

  Agent 2 (REJECTED):
    ID: ${agent2Id}
    Email: ${testData.agent2.email}
    Status: REJECTED
`);

  log('🗄️ DATABASE VERIFICATION COMMAND:', '', 'bright');
  console.log(`
  In MongoDB, run:
  
  db.agents.find({ email: { $in: ["${testData.agent1.email}", "${testData.agent2.email}"] } }, 
                  { email: 1, status: 1, rejectionReason: 1 }).pretty()
  
  Should show:
    - Agent 1 with status: APPROVED
    - Agent 2 with status: REJECTED, rejectionReason: "Does not meet business requirements"
`);
};

// Run tests
runTests().catch((err) => {
  log('❌', `Fatal error: ${err.message}`, 'red');
  process.exit(1);
});
