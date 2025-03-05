require('dotenv').config();
const express = require('express');
const { supabasePublic, supabaseService } = require('./config/supabase');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Default route
app.get('/', (req, res) => {
  res.redirect('/api/agents');
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