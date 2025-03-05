const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabasePublic = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const supabaseService = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

module.exports = { supabasePublic, supabaseService };