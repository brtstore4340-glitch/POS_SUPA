
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' }); // Adjust path if needed

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase env vars');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testBackend() {
  console.log('Testing Supabase Connection...');

  // 1. Test Database Access (Products)
  console.log('\n1. Testing Database Select (Products)...');
  const { data: products, error: dbError } = await supabase
    .from('products')
    .select('*')
    .limit(1);

  if (dbError) {
    console.error('DB Error:', dbError.message);
  } else {
    console.log('DB Success! Products found:', products.length);
  }

  // 2. Test Edge Function (list-products)
  console.log('\n2. Testing Edge Function (list-products)...');
  const { data: funcData, error: funcError } = await supabase.functions.invoke('list-products', {
    body: { limit: 1 }
  });

  if (funcError) {
    console.error('Function Error:', funcError.message);
  } else {
    console.log('Function Success! Response:', funcData);
  }
}

testBackend();
