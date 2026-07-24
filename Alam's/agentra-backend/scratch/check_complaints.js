const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Complaint = require('../src/models/Complaint');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;

async function check() {
  try {
    await mongoose.connect(MONGO_URI, { dbName: 'agentra' });
    const complaints = await Complaint.find();
    console.log('--- COMPLAINTS IN DB ---');
    console.log('Count:', complaints.length);
    complaints.forEach(c => {
      console.log(`ID: ${c._id}, Subject: ${c.subject}, User: ${c.userId}, Status: ${c.status}`);
    });
  } catch (err) {
    console.error('Error:', err);
  }
  process.exit(0);
}

check();
