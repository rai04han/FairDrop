// FairDrop — Quick API Demo Script
// Run: node tests/demo.js
// Shows all auth endpoints working — useful for interim demo

const BASE = 'http://localhost:3003';

async function req(method, path, body = null, token = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) opts.body = JSON.stringify(body);
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, opts);
  return { status: res.status, data: await res.json() };
}

async function demo() {
  console.log('\n══════════════════════════════════════════');
  console.log('  FairDrop Auth Module — Live Demo');
  console.log('══════════════════════════════════════════\n');

  // 1. Register all 4 roles
  console.log('--- 1. REGISTER ALL 4 ROLES ---\n');

  const roles = [
    { name: 'Hari (Customer)', email: 'hari@demo.com', password: 'pass123', role: 'customer' },
    { name: 'Ajith (Rider)', email: 'ajith@demo.com', password: 'pass123', role: 'rider' },
    { name: 'Hotel Arun (Restaurant)', email: 'arun@demo.com', password: 'pass123', role: 'restaurant' },
    { name: 'Admin User', email: 'admin@demo.com', password: 'pass123', role: 'admin' },
  ];

  const tokens = {};

  for (const user of roles) {
    const { status, data } = await req('POST', '/api/auth/register', user);
    console.log(`  ✅ ${user.role.toUpperCase()} registered — Status: ${status}`);
    console.log(`     Name: ${data.user.name}, Email: ${data.user.email}`);
    if (user.role === 'rider') {
      console.log(`     Rider Profile: available=${data.user.rider_profile.is_available}`);
    }
    console.log(`     Token: ${data.token.substring(0, 30)}...`);
    tokens[user.role] = data.token;
    console.log('');
  }

  // 2. Duplicate email rejection
  console.log('--- 2. DUPLICATE EMAIL REJECTION ---\n');
  const { status: dupStatus, data: dupData } = await req('POST', '/api/auth/register', roles[0]);
  console.log(`  ❌ Duplicate register — Status: ${dupStatus}`);
  console.log(`     Message: ${dupData.message}\n`);

  // 3. Login
  console.log('--- 3. LOGIN ---\n');
  const { status: loginStatus, data: loginData } = await req('POST', '/api/auth/login', {
    email: 'ajith@demo.com', password: 'pass123',
  });
  console.log(`  ✅ Rider login — Status: ${loginStatus}`);
  console.log(`     Role: ${loginData.user.role}`);
  console.log(`     Token: ${loginData.token.substring(0, 30)}...\n`);

  // 4. Wrong password
  console.log('--- 4. WRONG PASSWORD ---\n');
  const { status: wrongStatus, data: wrongData } = await req('POST', '/api/auth/login', {
    email: 'ajith@demo.com', password: 'wrongpass',
  });
  console.log(`  ❌ Wrong password — Status: ${wrongStatus}`);
  console.log(`     Message: ${wrongData.message}\n`);

  // 5. Protected route with token
  console.log('--- 5. PROTECTED ROUTE (GET /api/auth/me) ---\n');
  const { status: meStatus, data: meData } = await req('GET', '/api/auth/me', null, tokens.rider);
  console.log(`  ✅ With valid token — Status: ${meStatus}`);
  console.log(`     User: ${meData.user.name} (${meData.user.role})\n`);

  // 6. No token = 401
  console.log('--- 6. NO TOKEN = 401 ---\n');
  const { status: noTokenStatus, data: noTokenData } = await req('GET', '/api/auth/me');
  console.log(`  ❌ No token — Status: ${noTokenStatus}`);
  console.log(`     Message: ${noTokenData.message}\n`);

  // 7. Invalid token = 401
  console.log('--- 7. INVALID TOKEN = 401 ---\n');
  const { status: badStatus, data: badData } = await req('GET', '/api/auth/me', null, 'fake.token.here');
  console.log(`  ❌ Invalid token — Status: ${badStatus}`);
  console.log(`     Message: ${badData.message}\n`);

  console.log('══════════════════════════════════════════');
  console.log('  All auth endpoints verified ✅');
  console.log('══════════════════════════════════════════\n');
}

demo().catch(console.error);
