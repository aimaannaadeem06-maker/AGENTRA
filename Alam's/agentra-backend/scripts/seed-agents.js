require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Agent = require('./src/models/Agent');

const seedAgents = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/agentra');
        console.log('Connected to MongoDB');

        const existingAgents = await Agent.find();
        if (existingAgents.length > 0) {
            console.log(`${existingAgents.length} agents already exist. Skipping seeding.`);
            process.exit(0);
        }

        const agents = [
            {
                fullName: 'John Smith',
                email: 'john@test.com',
                password: await bcrypt.hash('password123', 10),
                phone: '+1234567890',
                businessName: 'Smith Travel Agency',
                cnic: '12345-6789012-3',
                status: 'PENDING_APPROVAL'
            },
            {
                fullName: 'Sarah Johnson',
                email: 'sarah@test.com',
                password: await bcrypt.hash('password123', 10),
                phone: '+1234567891',
                businessName: 'Johnson Tours',
                cnic: '12345-6789012-4',
                status: 'PENDING_APPROVAL'
            },
            {
                fullName: 'Mike Wilson',
                email: 'mike@test.com',
                password: await bcrypt.hash('password123', 10),
                phone: '+1234567892',
                businessName: 'Wilson Adventures',
                cnic: '12345-6789012-5',
                status: 'APPROVED'
            }
        ];

        for (const agentData of agents) {
            const agent = await Agent.create(agentData);
            console.log('Created agent:', agent.fullName, agent.status);
        }

        console.log('Seeding completed successfully');
        process.exit(0);
    } catch (error) {
        console.error('Error seeding agents:', error);
        process.exit(1);
    }
};

seedAgents();