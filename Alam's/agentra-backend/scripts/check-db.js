
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Agent = require('./src/models/Agent');

dotenv.config();

const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '')
  .trim()
  .replace(/^["']|["']$/g, '');

const checkAgents = async () => {
    try {
        await mongoose.connect(MONGO_URI, { dbName: 'agentra' });
        console.log('Connected to MongoDB');

        const agents = await Agent.find({});
        console.log('------------------------------------------------');
        console.log(`TOTAL AGENTS IN DB: ${agents.length}`);
        console.log('------------------------------------------------');
        
        agents.forEach(a => {
            console.log(`ID: ${a._id}`);
            console.log(`Name: ${a.fullName}`);
            console.log(`Email: ${a.email}`);
            console.log(`Status: ${a.status}`);
            console.log(`isVerified: ${a.isVerified}`);
            console.log(`emailVerified: ${a.emailVerified}`);
            console.log('------------------------------------------------');
        });

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

checkAgents();
