require('dotenv').config();
const express = require('express');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const port = process.env.PORT || 3000;

// Initialize Supabase clients
const supabasePublic = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const supabaseService = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

// Middleware
app.use(express.json());

// Default route
app.get('/', (req, res) => {
  res.redirect('/api/agents'); // Redirect to agents endpoint or send a welcome message
  // Or: res.send('Welcome to AgentPlate!');
});

// Routes
const routes = require('./routes');
app.use('/api', routes);

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(port, () => {
  console.log(`AgentPlate running on http://localhost:${port}`);
});

module.exports = { supabasePublic, supabaseService }; // Export clients