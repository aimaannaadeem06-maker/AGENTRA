const mongoose = require('mongoose');
const Complaint = require('./src/models/Complaint');
const User = require('./src/models/User');
const Agent = require('./src/models/Agent');

async function seedComplaints() {
  try {
    // Connect to MongoDB
    const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/agentra';
    await mongoose.connect(MONGO_URI, {
      dbName: 'agentra',
    });
    console.log('✅ Connected to MongoDB');

    // Get some sample users and agents
    const users = await User.find().limit(3);
    const agents = await Agent.find().limit(3);

    if (users.length === 0 || agents.length === 0) {
      console.log('⚠️ No users or agents found. Creating sample complaints with dummy IDs...');

      // Create sample complaints with dummy IDs
      const sampleComplaints = [
        {
          userId: new mongoose.Types.ObjectId(),
          agentId: new mongoose.Types.ObjectId(),
          subject: 'Poor Service Quality',
          description: 'The travel agent was not responsive and provided inaccurate information about the booking.',
          status: 'OPEN',
          ownerResponse: ''
        },
        {
          userId: new mongoose.Types.ObjectId(),
          agentId: new mongoose.Types.ObjectId(),
          subject: 'Booking Cancellation Issue',
          description: 'I tried to cancel my booking but the agent refused and charged cancellation fees.',
          status: 'IN_PROGRESS',
          ownerResponse: 'We are investigating this matter and will get back to you within 24 hours.'
        },
        {
          userId: new mongoose.Types.ObjectId(),
          agentId: new mongoose.Types.ObjectId(),
          subject: 'Package Price Discrepancy',
          description: 'The final price was much higher than what was quoted initially.',
          status: 'RESOLVED',
          ownerResponse: 'We have refunded the difference and apologized for the inconvenience.'
        },
        {
          userId: new mongoose.Types.ObjectId(),
          agentId: new mongoose.Types.ObjectId(),
          subject: 'Communication Problems',
          description: 'The agent stopped responding to my messages after payment was made.',
          status: 'OPEN',
          ownerResponse: ''
        },
        {
          userId: new mongoose.Types.ObjectId(),
          agentId: new mongoose.Types.ObjectId(),
          subject: 'Wrong Hotel Booking',
          description: 'I was booked in a different hotel than what was agreed upon.',
          status: 'RESOLVED',
          ownerResponse: 'The booking has been corrected and we have arranged for the hotel transfer.'
        }
      ];

      await Complaint.insertMany(sampleComplaints);
      console.log(`✅ Created ${sampleComplaints.length} sample complaints`);
    } else {
      // Create complaints with real user/agent IDs
      const sampleComplaints = [
        {
          userId: users[0]?._id,
          agentId: agents[0]?._id,
          subject: 'Poor Service Quality',
          description: 'The travel agent was not responsive and provided inaccurate information about the booking.',
          status: 'OPEN',
          ownerResponse: ''
        },
        {
          userId: users[1]?._id || users[0]?._id,
          agentId: agents[1]?._id || agents[0]?._id,
          subject: 'Booking Cancellation Issue',
          description: 'I tried to cancel my booking but the agent refused and charged cancellation fees.',
          status: 'IN_PROGRESS',
          ownerResponse: 'We are investigating this matter and will get back to you within 24 hours.'
        },
        {
          userId: users[2]?._id || users[0]?._id,
          agentId: agents[2]?._id || agents[0]?._id,
          subject: 'Package Price Discrepancy',
          description: 'The final price was much higher than what was quoted initially.',
          status: 'RESOLVED',
          ownerResponse: 'We have refunded the difference and apologized for the inconvenience.'
        }
      ];

      await Complaint.insertMany(sampleComplaints);
      console.log(`✅ Created ${sampleComplaints.length} sample complaints with real user/agent IDs`);
    }

    console.log('🎉 Sample complaints seeded successfully!');
  } catch (error) {
    console.error('❌ Error seeding complaints:', error);
  } finally {
    await mongoose.connection.close();
    console.log('🔌 Database connection closed');
  }
}

seedComplaints();