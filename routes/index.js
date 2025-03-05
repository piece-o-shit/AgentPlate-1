const express = require('express');
const router = express.Router();
const { supabasePublic, supabaseService } = require('../index');
const jwt = require('jsonwebtoken');

// Middleware to verify JWT
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized: No token provided' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Get all agents (authenticated users only)
router.get('/agents', verifyToken, async (req, res) => {
  const { user } = req;
  const { data, error } = await supabasePublic
    .from('agents')
    .select('*');

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// Create a new agent (admin-only, using service key)
router.post('/agents', verifyToken, async (req, res) => {
  const { user } = req;
  const { data: userRole, error: roleError } = await supabasePublic
    .from('user_roles')
    .select('role')
    .eq('user_id', user.sub) // 'sub' is typically the user ID in JWT
    .single();

  if (roleError || userRole.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }

  const { name, description } = req.body;
  const { data, error } = await supabaseService
    .from('agents')
    .insert([{ name, description, creator_id: user.sub }])
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// Get user profile (including display_name)
router.get('/profile', verifyToken, async (req, res) => {
  const { user } = req;
  const { data, error } = await supabasePublic
    .from('profiles')
    .select('display_name')
    .eq('id', user.sub)
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// Login endpoint to generate JWT (example)
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const { data, error } = await supabasePublic.auth.signInWithPassword({ email, password });

  if (error) return res.status(401).json({ error: error.message });

  const token = jwt.sign({ sub: data.user.id, role: (await supabasePublic.from('user_roles').select('role').eq('user_id', data.user.id).single()).data?.role || 'user' }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRY });
  res.json({ token });
});

module.exports = router;