const User = require('../models/User');
const Agent = require('../models/Agent');
const Owner = require('../models/Owner');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// ================= TOKEN =================
const generateToken = (id, role) => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
};

// ================= USER =================
const registerUser = async (req, res) => {
  try {
    const { fullName, email, password, phone } = req.body;

    if (!fullName || !email || !password || !phone) {
      return res.status(400).json({ success: false, message: 'All fields are required: fullName, email, password, phone' });
    }

    const existing = await User.findOne({ email: email.toLowerCase().trim() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'An account with this email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      fullName: fullName.trim(),
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      password: hashedPassword,
    });

    const token = generateToken(user._id, user.role);

    const { password: _, ...userData } = user.toObject();

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      token,
      user: userData,
    });

  } catch (err) {
    console.error('❌ REGISTER USER ERROR:', err.message);
    // Handle MongoDB duplicate key errors
    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern)[0];
      return res.status(400).json({ success: false, message: `This ${field} is already registered` });
    }
    res.status(500).json({ success: false, message: 'Server error during registration. Please try again.' });
  }
};

// ================= USER LOGIN =================
const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    // Case-insensitive email lookup
    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      return res.status(404).json({ success: false, message: 'No account found with this email' });
    }

    // Check if account is active
    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Your account has been deactivated. Please contact support.' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Incorrect password. Please try again.' });
    }

    const token = generateToken(user._id, user.role);

    const { password: _, ...userData } = user.toObject();

    res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      user: userData,
    });

  } catch (err) {
    console.error('❌ LOGIN USER ERROR:', err.message);
    res.status(500).json({ success: false, message: 'Server error during login. Please try again.' });
  }
};

// ================= AGENT SIGNUP =================
const registerAgent = async (req, res) => {
  try {
    console.log('🔥 REGISTER AGENT REQUEST BODY:', req.body);
    const { fullName, email, password, phone, businessName, cnic } = req.body;

    if (!fullName || !email || !password || !phone || !businessName || !cnic) {
      return res.status(400).json({ success: false, message: 'All fields are required: fullName, email, password, phone, businessName, cnic' });
    }

    const existing = await Agent.findOne({ email: email.toLowerCase().trim() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'An agent account with this email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const agent = await Agent.create({
      fullName: fullName.trim(),
      email: email.toLowerCase().trim(),
      phone: phone.trim(),
      businessName: businessName.trim(),
      cnic: cnic.trim(),
      password: hashedPassword,
      status: 'PENDING_APPROVAL',
    });

    console.log('✅ AGENT SAVED:', agent._id, agent.email);
    const { password: _, ...agentData } = agent.toObject();

    return res.status(201).json({
      success: true,
      message: 'Your account request has been submitted. Please wait for owner approval (within 24 hours).',
      status: 'PENDING_APPROVAL',
      agent: agentData,
    });

  } catch (err) {
    console.error('❌ REGISTER AGENT ERROR:', err.message, err.stack);
    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern)[0];
      return res.status(400).json({ success: false, message: `This ${field} is already registered` });
    }
    return res.status(500).json({ success: false, message: 'Server error during registration. Please try again.' });
  }
};

// ================= AGENT LOGIN =================
const loginAgent = async (req, res) => {
  try {
    const { email, password } = req.body;

    const agent = await Agent.findOne({ email: email.toLowerCase() });
    if (!agent) {
      console.log(`❌ [LOGIN] Agent not found: ${email}`);
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    const isMatch = await bcrypt.compare(password, agent.password);
    console.log(`🔑 [LOGIN] Agent: ${email} | Found: true | Status: ${agent.status} | Password Match: ${isMatch}`);

    if (!isMatch) {
      console.log(`❌ [LOGIN] Password mismatch for: ${email}`);
      return res.status(400).json({ success: false, message: 'Invalid credentials' });
    }

    if (agent.status === 'PENDING_APPROVAL') {
      console.log(`⚠️ [LOGIN] Agent ${email} blocked: Status is PENDING_APPROVAL`);
      return res.status(403).json({
        success: false,
        message: 'Your account is not yet approved by owner.',
      });
    }

    if (agent.status === 'REJECTED') {
      return res.status(403).json({
        success: false,
        message: 'Your account has been rejected.',
      });
    }

    if (agent.status === 'BLOCKED') {
      return res.status(403).json({
        success: false,
        message: 'Your account has been blocked by owner. Please contact support.',
      });
    }

    const token = generateToken(agent._id, agent.role);

    const { password: _, ...agentData } = agent.toObject();

    res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      agent: agentData,
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= OWNER LOGIN =================
const loginOwner = async (req, res) => {
  try {
    const { email, password } = req.body;

    const owner = await Owner.findOne({ email });
    if (!owner) {
      return res.status(404).json({ success: false, message: 'Owner not found' });
    }

    const isMatch = await bcrypt.compare(password, owner.password);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Invalid credentials' });
    }

    const token = generateToken(owner._id, owner.role);

    const { password: _, ...ownerData } = owner.toObject();

    res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      owner: ownerData,
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= PROFILE =================
const getAgentProfile = async (req, res) => {
  try {
    const agent = await Agent.findById(req.user.id).select('-password');

    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    res.status(200).json({ success: true, agent });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= UPDATE PROFILE =================
const updateAgentProfile = async (req, res) => {
  try {
    const allowed = [
      'fullName',
      'businessName',
      'phone',
      'location',
      'bio',
      'profileImage',
      'refundPolicy',
      'cancellationPolicy',
    ];

    const updateData = {};

    allowed.forEach((key) => {
      if (req.body[key] !== undefined) {
        updateData[key] = req.body[key];
      }
    });

    const agent = await Agent.findByIdAndUpdate(req.user.id, updateData, {
      new: true,
    }).select('-password');

    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      agent,
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ================= LOGOUT =================
const logoutUser = async (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Logout successful',
  });
};

// ================= owner =================
const getPendingAgents = async (req, res) => {
  try {
    console.log('🔥 GET PENDING AGENTS REQUEST');
    const agents = await Agent.find({ status: 'PENDING_APPROVAL' })
      .select('-password')
      .sort({ createdAt: -1 });

    console.log(`✅ Found ${agents.length} pending agents`);
    console.log('PENDING IDS:', agents.map(a => a._id));
    res.status(200).json({
      success: true,
      count: agents.length,
      agents,
    });

  } catch (err) {
    console.error('❌ GET PENDING AGENTS ERROR:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
};

const getAllAgents = async (req, res) => {
  try {
    const agents = await Agent.find({})
      .select('-password')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: agents.length,
      agents,
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

const approveAgent = async (req, res) => {
  try {
    console.log('🔥 APPROVE AGENT REQUEST:', req.params.agentId);
    console.log('🔥 REQUEST BODY:', req.body);

    const agent = await Agent.findById(req.params.agentId);

    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    if (agent.status !== 'PENDING_APPROVAL') {
      return res.status(400).json({ success: false, message: 'Not in pending state' });
    }

    console.log('✅ UPDATING AGENT STATUS TO APPROVED...');
    const updatedAgent = await Agent.findByIdAndUpdate(
      req.params.agentId,
      { 
        status: 'APPROVED', 
        isVerified: true, 
        emailVerified: true 
      },
      { new: true, runValidators: true }
    );

    if (!updatedAgent) {
      console.error('❌ APPROVE AGENT: Failed to find agent during update');
      return res.status(404).json({ success: false, message: 'Agent lost during update process' });
    }

    console.log('✅ AGENT STATUS UPDATED SUCCESSFULLY:', updatedAgent.email, 'New Status:', updatedAgent.status);
    const { password: _, ...data } = updatedAgent.toObject();

    res.status(200).json({
      success: true,
      message: 'Agent approved and verified successfully',
      agent: data,
    });

  } catch (err) {
    console.error('❌ APPROVE AGENT ERROR:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
};

const rejectAgent = async (req, res) => {
  try {
    console.log('🔥 REJECT AGENT REQUEST:', req.params.agentId);
    console.log('🔥 REQUEST BODY:', req.body);
    const { reason } = req.body;

    const agent = await Agent.findById(req.params.agentId);

    if (!agent) {
      return res.status(404).json({ success: false, message: 'Agent not found' });
    }

    if (agent.status !== 'PENDING_APPROVAL') {
      return res.status(400).json({ success: false, message: 'Not in pending state' });
    }

    const updatedAgent = await Agent.findByIdAndUpdate(
      req.params.agentId,
      { 
        status: 'REJECTED', 
        rejectionReason: reason || 'Rejected by owner',
        isVerified: false
      },
      { new: true }
    );

    if (!updatedAgent) {
      console.error('❌ REJECT AGENT: Failed to update agent in DB');
      return res.status(500).json({ success: false, message: 'Failed to update agent status' });
    }

    console.log('✅ AGENT REJECTED AND SAVED:', updatedAgent.email, 'Status:', updatedAgent.status);
    const { password: _, ...data } = updatedAgent.toObject();

    res.status(200).json({
      success: true,
      message: 'Agent rejected',
      agent: data,
    });

  } catch (err) {
    console.error('❌ REJECT AGENT ERROR:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = {
  registerUser,
  loginUser,
  registerAgent,
  loginAgent,
  loginOwner,
  getAgentProfile,
  updateAgentProfile,
  logoutUser,
  getPendingAgents,
  approveAgent,
  rejectAgent,
};
