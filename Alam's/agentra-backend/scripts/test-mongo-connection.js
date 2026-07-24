const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = (process.env.MONGO_URI || '')
  .trim()
  .replace(/^["']|["']$/g, '');

console.log('🔍 MongoDB Connection Test');
console.log('==========================');
console.log('MONGO_URI:', MONGO_URI ? MONGO_URI.substring(0, 50) + '...' : '❌ NOT SET');
console.log('NODE_ENV:', process.env.NODE_ENV);
console.log('PORT:', process.env.PORT);
console.log('');

if (!MONGO_URI) {
  console.error('❌ MONGO_URI is missing in .env file!');
  process.exit(1);
}

(async () => {
  try {
    console.log('⏳ Connecting to MongoDB...');
    await mongoose.connect(MONGO_URI, {
      dbName: 'agentra',
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
      connectTimeoutMS: 10000,
      retryWrites: true,
    });

    console.log('✅ MongoDB Connected Successfully!');
    console.log('📊 Connection Status:', mongoose.connection.readyState);
    console.log('📍 Database:', mongoose.connection.db?.databaseName);
    console.log('🖥️  Host:', mongoose.connection.host);
    
    // List collections
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('\n📦 Collections in database:');
    collections.forEach((col) => console.log('  - ' + col.name));

    await mongoose.disconnect();
    console.log('\n✅ Test completed successfully!');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ Connection Failed:');
    console.error('Error Message:', err.message);
    console.error('Error Code:', err.code);
    console.error('\n⚠️  Common Issues:');
    console.error('  1. Invalid MongoDB URI credentials');
    console.error('  2. IP address not whitelisted in MongoDB Atlas');
    console.error('  3. Network connectivity issues');
    console.error('  4. MongoDB cluster not running');
    process.exit(1);
  }
})();
