const mongoose = require('mongoose');

const itineraryDaySchema = new mongoose.Schema({
  day: { type: Number, required: true },
  title: { type: String, default: '' },
  description: { type: String, default: '' },
}, { _id: false });

const packageSchema = new mongoose.Schema({

  // -------- Relationships --------
  agentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Agent',
    required: true
  },

  // -------- Basic Info --------
  title: {
    type: String,
    required: true,
    trim: true
  },

  description: {
    type: String,
    required: true
  },

  location: {
    type: String,
    required: true
  },

  price: {
    type: Number,
    required: true
  },

  duration: {
    type: String,
    required: true
  },

  province: {
    type: String,
    default: ''
  },

  departureCity: {
    type: String,
    default: ''
  },

  departureTime: {
    type: String,
    default: ''
  },

  departureLocation: {
    type: String,
    default: ''
  },

  // -------- What's Included --------
  includes: {
    transport: { type: Boolean, default: false },
    accommodation: { type: Boolean, default: false },
    meals: { type: Boolean, default: false },
  },

  // -------- What's Not Included --------
  notIncluded: {
    type: String,
    default: ''
  },

  // -------- Trip Highlights --------
  tripHighlights: {
    type: String,
    default: ''
  },

  // -------- Daily Itinerary --------
  itinerary: [itineraryDaySchema],

  // -------- Availability --------
  availableSeats: {
    type: Number,
    required: true
  },

  startDate: Date,
  endDate: Date,

  availableDates: [Date],

  // -------- Media --------
  images: [String],
  image: {
    type: String,
    default: ''
  },

  // -------- Rating & Reviews --------
  rating: {
    type: Number,
    default: 0
  },

  totalReviews: {
    type: Number,
    default: 0
  },

  // -------- Featured & Discount --------
  isFeatured: {
    type: Boolean,
    default: false
  },

  hasDiscount: {
    type: Boolean,
    default: false
  },

  discountPercentage: {
    type: Number,
    default: 0
  },

  // -------- AI Indexing --------
  tags: [String],

  // -------- Promotion --------
  promotedAt: {
    type: Date,
    default: null
  },

  // -------- Visibility --------
  isActive: {
    type: Boolean,
    default: true
  }

}, { timestamps: true });

module.exports = mongoose.model('Package', packageSchema);
