
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Agent = require('./src/models/Agent');

dotenv.config();

const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '')
  .trim()
  .replace(/^["']|["']$/g, '');

const forceApprove = async () => {
    try {
        await mongoose.connect(MONGO_URI, { dbName: 'agentra' });
        console.log('Connected to MongoDB');

        const result = await Agent.updateMany(
            { status: 'PENDING_APPROVAL' },
            { 
                status: 'APPROVED', 
                isVerified: true, 
                emailVerified: true 
            }
        );

        console.log(`✅ Force approved ${result.modifiedCount} pending agents.`);
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

forceApprove();
