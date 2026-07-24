require('dotenv').config();
const mongoose = require('mongoose');
const dns = require('dns');
const bcrypt = require('bcryptjs');
const Owner = require('./src/models/Owner');

const createAdmin = async () => {
    try {
        const MONGO_URI = (process.env.MONGO_URI || process.env.MONGODB_URI || '')
            .trim()
            .replace(/^["']|["']$/g, '');

        if (MONGO_URI.startsWith('mongodb+srv://')) {
            console.log('🌐 Using public DNS for Atlas SRV resolution');
            dns.setServers(['8.8.8.8', '1.1.1.1']);
        }

        await mongoose.connect(MONGO_URI, {
            dbName: 'agentra',
            serverSelectionTimeoutMS: 10000,
            socketTimeoutMS: 45000,
            connectTimeoutMS: 10000,
        });
        console.log('Connected to MongoDB');

        const email = 'admin@agentra.com';
        const password = 'admin123'; // Real password to be hashed
        const existingAdmin = await Owner.findOne({ email });

        if (existingAdmin) {
            console.log('Admin already exists');
            process.exit(0);
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const admin = await Owner.create({
            fullName: 'Super Admin',
            email,
            password: hashedPassword,
            role: 'OWNER'
        });

        console.log('Admin created successfully:', admin);
        process.exit(0);
    } catch (error) {
        console.error('Error creating admin:', error);
        process.exit(1);
    }
};

createAdmin();
