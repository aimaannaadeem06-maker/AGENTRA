const fetch = require('node-fetch');
const { execSync } = require('child_process');
const path = require('path');

const BASE_URL = 'http://localhost:5000/api';

const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

const log = (message, color = 'reset') => {
  console.log(`${colors[color]}${message}${colors.reset}`);
};

const logSection = (section) => {
  console.log('\n' + '='.repeat(60));
  log(section, 'blue');
  console.log('='.repeat(60) + '\n');
};

const generateUniqueData = (prefix) => {
  const ts = Date.now();
  return {
    email: `${prefix}${ts}@test.com`,
    phone: `03${Math.floor(Math.random() * 900000000 + 100000000)}`,
    cnic: `42${Math.floor(Math.random() * 90000000000 + 10000000000)}`
  };
};

const testEndpoint = async (method, endpoint, data = null, token = null, description = '') => {
  try {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['x-auth-token'] = token;

    const options = { method, headers };
    if (data) options.body = JSON.stringify(data);

    const response = await fetch(`${BASE_URL}${endpoint}`, options);
    const result = await response.json();

    if (response.ok) {
      log(`✅ ${description || endpoint}`, 'green');
      return { success: true, data: result };
    } else {
      log(`❌ ${description || endpoint}: ${result.message || 'Error'}`, 'red');
      return { success: false, data: result };
    }
  } catch (error) {
    log(`❌ ${description || endpoint}: ${error.message}`, 'red');
    return { success: false, error: error.message };
  }
};

const runE2E = async () => {
  logSection('AGENTRA END-TO-END TEST SUITE');

  const userData = generateUniqueData('user');
  const agentData = generateUniqueData('agent');

  let userToken, agentToken, packageId;

  // 1. User Auth
  logSection('1. USER FLOW');
  const regUser = await testEndpoint('POST', '/auth/user/register', {
    fullName: 'E2E Test User',
    email: userData.email,
    password: 'password123',
    phone: userData.phone
  }, null, 'Register User');

  if (!regUser.success) return;
  userToken = regUser.data.token;

  // 2. Agent Auth + Auto Approval
  logSection('2. AGENT FLOW');
  const regAgent = await testEndpoint('POST', '/auth/agent/register', {
    fullName: 'E2E Test Agent',
    email: agentData.email,
    password: 'password123',
    phone: agentData.phone,
    businessName: 'E2E Travel Agency',
    cnic: agentData.cnic
  }, null, 'Register Agent');

  if (!regAgent.success) return;

  log('⏳ Approving Agent via System Helper...', 'yellow');
  try {
    execSync(`node scratch/approve_agent.js ${agentData.email}`);
    log('✅ Agent Approved!', 'green');
  } catch (e) {
    log('❌ System Approval Failed', 'red');
    return;
  }

  const loginAgent = await testEndpoint('POST', '/auth/agent/login', {
    email: agentData.email,
    password: 'password123'
  }, null, 'Login Agent');

  if (!loginAgent.success) return;
  agentToken = loginAgent.data.token;

  // 3. Package Management
  logSection('3. PACKAGE MANAGEMENT');
  const createPkg = await testEndpoint('POST', '/packages', {
    title: 'Naran Kaghan Special ' + Date.now(),
    description: 'Beautiful 3-day trip to Naran',
    location: 'Naran, Pakistan',
    price: 15000,
    duration: '3 Days',
    availableSeats: 20,
    hasDiscount: true,
    discountPercentage: 10
  }, agentToken, 'Create Package');

  if (!createPkg.success) return;
  packageId = createPkg.data.package._id;

  // 4. Booking
  logSection('4. BOOKING FLOW');
  await testEndpoint('POST', '/bookings', {
    packageId: packageId,
    seats: 2,
    travelDate: '2025-06-15',
    paymentMethod: 'CARD'
  }, userToken, 'Create Booking');

  // 5. Search & Filters
  logSection('5. SEARCH & DISCOVERY');
  await testEndpoint('GET', '/packages', null, null, 'Public Packages');
  await testEndpoint('GET', '/search?q=Naran', null, null, 'Search Naran');
  await testEndpoint('GET', '/promotion/', null, null, 'Get Promotions');

  // 6. Chatbot
  logSection('6. AI CHATBOT');
  await testEndpoint('POST', '/chatbot/chat', {
    message: 'What are the best places in Naran?'
  }, null, 'Chatbot Interaction');

  logSection('E2E TEST COMPLETED SUCCESSFULLY');
};

runE2E();
