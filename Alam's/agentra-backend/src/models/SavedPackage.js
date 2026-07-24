const mongoose = require('mongoose');

const savedPackageSchema = new mongoose.Schema({

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  packageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Package',
    required: true
  },

  notes: {
    type: String,
    default: ''
  },

  savedAt: {
    type: Date,
    default: Date.now
  }

}, { timestamps: true });

savedPackageSchema.index({ userId: 1, packageId: 1 }, { unique: true });

module.exports = mongoose.model('SavedPackage', savedPackageSchema);
