const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

async function testApprove() {
  try {
    // 1. Login as Owner
    console.log('Logging in as owner...');
    const loginRes = await axios.post(`${BASE_URL}/auth/owner/login`, {
      email: 'admin@agentra.com',
      password: 'password123'
    });
    
    const token = loginRes.data.token;
    console.log('Token obtained.');

    // 2. Get pending agents
    const agentsRes = await axios.get(`${BASE_URL}/admin/agents`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    const pending = agentsRes.data.agents.filter(a => a.status === 'PENDING_APPROVAL');
    console.log(`Found ${pending.length} pending agents.`);

    if (pending.length > 0) {
      const agentId = pending[0]._id;
      console.log(`Approving agent ${agentId}...`);
      
      const approveRes = await axios.patch(`${BASE_URL}/admin/approve-agent/${agentId}`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      console.log('Approval response:', approveRes.data);
    } else {
      console.log('No pending agents to test with.');
    }
  } catch (err) {
    console.error('Error:', err.response ? err.response.data : err.message);
  }
}

testApprove();
