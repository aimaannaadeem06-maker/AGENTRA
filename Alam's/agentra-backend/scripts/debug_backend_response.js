const fetch = require('node-fetch');

async function checkHealth() {
    const url = 'http://localhost:5000/api/auth/admin/agents/pending'; // Test admin endpoint
    console.log(`Checking URL: ${url}`);

    try {
        const response = await fetch(url, {
            method: 'GET',
            headers: { 'Content-Type': 'application/json' }
        });

        console.log(`Status: ${response.status} ${response.statusText}`);
        const text = await response.text();
        console.log('Response body start:', text.substring(0, 500)); // Print first 500 chars
    } catch (error) {
        console.error('Fetch error:', error);
    }
}

checkHealth();
