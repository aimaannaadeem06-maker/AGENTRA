const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Owner = require('./src/models/Owner');
const dotenv = require('dotenv');

dotenv.config();

const MONGO_URI = (process.env.MONGO_URI || '').trim().replace(/^["']|["']$/g, '');

const seedOwner = async () => {
  try {
    await mongoose.connect(MONGO_URI, { dbName: 'agentra' });
    console.log('✅ Connected to MongoDB');

    const existing = await Owner.findOne({ email: 'admin@agentra.com' });
    const hashedPassword = await bcrypt.hash('adminpassword', 10);
    
    if (existing) {
      existing.password = hashedPassword;
      await existing.save();
      console.log('✅ Owner password updated');
      process.exit(0);
    }
    await Owner.create({
      fullName: 'System Admin',
      email: 'admin@agentra.com',
      password: hashedPassword,
      role: 'OWNER'
    });

    console.log('✅ Owner seeded successfully');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error seeding owner:', err.message);
    process.exit(1);
  }
};

seedOwner();
