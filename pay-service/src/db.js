// FairDrop Pay Service — MySQL Connection Pool
// Owner: Raihan
//
// Uses mysql2/promise for async/await support.
// Connection config is read from environment variables (.env file).
// The pool manages multiple connections automatically —
// no need to manually open/close connections per request.

const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'fairdrop_pay',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

/**
 * Tests the database connection.
 * Called during server startup to fail fast if MySQL is unreachable.
 *
 * @returns {Promise<boolean>} true if connection succeeds
 * @throws {Error} if connection fails
 */
async function testConnection() {
  const connection = await pool.getConnection();
  try {
    await connection.ping();
    console.log('✓ MySQL connection established — database:', process.env.DB_NAME || 'fairdrop_pay');
    return true;
  } finally {
    connection.release();
  }
}

module.exports = { pool, testConnection };
