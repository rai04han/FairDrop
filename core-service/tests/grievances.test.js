// ============================================================================
// FairDrop — Grievances Integration Tests (FR-50)
// ============================================================================

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const http = require('http');
const app = require('../src/app');
const env = require('../src/config/env');
const Grievance = require('../src/modules/grievances/Grievance.model');

describe('Grievance API Tests (FR-50, Fairwork Principle 2)', () => {
  let server;
  let baseUrl;

  before(async () => {
    await mongoose.connect(env.MONGODB_URI);
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  after(async () => {
    await Grievance.deleteMany({ subject: /Test Grievance/ });
    await new Promise((resolve) => server.close(resolve));
    await mongoose.disconnect();
  });

  test('rejects grievance without subject with 400', async () => {
    const res = await fetch(`${baseUrl}/api/grievances`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category: 'pay_discrepancy',
        description: 'Missing wait time pay for 15 minutes wait.',
      }),
    });

    const data = await res.json();
    assert.equal(res.status, 400);
    assert.equal(data.success, false);
    assert.match(data.message, /Subject is required/i);
  });

  test('rejects grievance without description with 400', async () => {
    const res = await fetch(`${baseUrl}/api/grievances`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category: 'pay_discrepancy',
        subject: 'Test Grievance - Missing wait time pay',
      }),
    });

    const data = await res.json();
    assert.equal(res.status, 400);
    assert.equal(data.success, false);
    assert.match(data.message, /Description is required/i);
  });

  test('submits grievance successfully with 201 and returns Case ID (FR-50)', async () => {
    const res = await fetch(`${baseUrl}/api/grievances`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category: 'pay_discrepancy',
        order_id: 'ORD-KL02-TEST-99',
        subject: 'Test Grievance - Minimum wage floor discrepancy',
        description: 'Active for 3 hours today in Kollam Central but floor top-up was not applied correctly.',
      }),
    });

    const data = await res.json();
    assert.equal(res.status, 201);
    assert.equal(data.success, true);
    assert.ok(data.case_id.startsWith('GRV-'));
    assert.equal(data.grievance.subject, 'Test Grievance - Minimum wage floor discrepancy');
    assert.equal(data.grievance.order_id, 'ORD-KL02-TEST-99');
    assert.equal(data.grievance.status, 'submitted');
  });
});
