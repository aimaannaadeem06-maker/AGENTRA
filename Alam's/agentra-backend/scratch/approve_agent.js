const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Agent = require('../src/models/Agent');

dotenv.config();

const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '')
  .trim()
  .replace(/^["']|["']$/g, '');

const approveAgent = async (email) => {
  try {
    await mongoose.connect(MONGO_URI, { dbName: 'agentra' });
    const result = await Agent.findOneAndUpdate(
      { email },
      { status: 'APPROVED' },
      { new: true }
    );
    if (result) {
      console.log(`✅ Agent ${email} approved successfully!`);
    } else {
      console.log(`❌ Agent ${email} not found.`);
    }
    await mongoose.connection.close();
  } catch (err) {
    console.error('❌ Error approving agent:', err.message);
    process.exit(1);
  }
};

const email = process.argv[2];
if (!email) {
  console.log('Usage: node approve_agent.js <email>');
  process.exit(1);
}

approveAgent(email);
