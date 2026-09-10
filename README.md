# FairDrop

**Pay Transparency & Equity Engine for Gig Delivery Workers**

MCA Mini Project — 23MCAM307 | TKM College of Engineering, Kollam, Kerala

## Problem

Gig delivery platforms in India use threshold-based ("cliff") incentive structures and opaque algorithmic management. Workers are forced into 10–12 hour workdays, penalized for factors outside their control, and assigned geographically unfair orders. No platform in India currently scores above 6/10 on Fairwork India's five-principle evaluation (Fairwork India Ratings 2024).

FairDrop proposes and implements transparent, worker-fair pay policies that remain operationally viable for the platform.

## What FairDrop Addresses

- **Incentive cliff trap** — Cliff bonus replaced with linear per-delivery pay
- **Out-of-zone assignment** — Dynamic zone reassignment with a configurable radius cap
- **Unverified delay penalties** — Delay context flags with verification architecture (mocked in prototype)
- **Pay opacity** — Formula published to rider before acceptance; line-by-line breakdown after delivery
- **Restaurant wait time** — Configurable wait compensation threshold *(partial)*
- **Minimum earnings floor** — Configurable floor aligned with Kerala minimum wage *(partial)*

## What FairDrop Does Not Address

- Real GPS tracking or live location
- Real payment gateway or fund disbursement
- Live Traffic / Railway API (architecture documented; prototype uses mock flags)
- Union recognition or collective bargaining (out of scope)
- Production-grade scaling or security hardening

## Tech Stack

| Layer | Technology | Port | Owner |
|---|---|---|---|
| Pay Engine | Node.js + Express + MySQL | 3001 | Raihan |
| Zone Assignment | Node.js + Express + MySQL | 3002 | Raihan |
| Auth | Node.js + Express + MongoDB | 3003 | Harikrishnan |
| Order Flow | Node.js + Express + MongoDB | 3004 | Harikrishnan |
| Frontend | Flutter (Dart) — Android | — | Shared |

## Project Structure

```
FairDrop/
├── pay-service/                    # Pay Engine + Admin Config (Port 3001)
│   ├── src/
│   │   ├── server.js               # Express entry point
│   │   ├── db.js                   # MySQL connection pool
│   │   ├── payEngine.js            # Pure pay calculation logic (no DB, no HTTP)
│   │   ├── seed.js                 # Database initialization script
│   │   └── routes/
│   │       ├── payRoutes.js        # POST /api/pay/calculate, GET /api/pay/history
│   │       └── adminRoutes.js      # GET/PUT /api/admin/pay-config
│   ├── config/
│   │   └── constants.js            # Pay constants (Kerala baseline defaults)
│   ├── tests/
│   │   └── payEngine.test.js       # 24 unit tests (Node.js built-in runner)
│   ├── package.json
│   └── .env.example                # Environment variable template
├── database/
│   ├── mysql/schema.sql            # Pay Engine tables (riders, pay_configs, deliveries, earnings)
│   └── mongodb/collections.md      # Auth/Order collection design (Harikrishnan)
└── docs/
    └── api-contract.md             # POST /api/pay/calculate — finalized contract
```

## Getting Started

### Prerequisites

- **Node.js** v18+ (`node --version`)
- **MySQL** 8.x (`mysql --version`)

### 1. Clone and install

```bash
git clone https://github.com/rai04han/FairDrop.git
cd FairDrop/pay-service
npm install
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and set your MySQL password:

```
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=fairdrop_pay
PORT=3001
```

### 3. Initialize the database

```bash
npm run seed
```

This creates the `fairdrop_pay` database, tables, Kerala baseline pay config, and 2 demo riders.

### 4. Start the server

```bash
npm start
```

Server runs on `http://localhost:3001`. Verify with:

```bash
curl http://localhost:3001/api/health
```

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Health check — verifies server and MySQL connection |
| `POST` | `/api/pay/calculate` | Calculate pay for a completed delivery ([full contract](docs/api-contract.md)) |
| `GET` | `/api/pay/history/:rider_id` | Earnings history for rider dashboard chart |
| `GET` | `/api/admin/pay-config` | Get active pay configuration |
| `PUT` | `/api/admin/pay-config` | Update pay config (7-day advance notice enforced) |

## Running Tests

```bash
cd pay-service
npm test
```

24 unit tests across 7 describe blocks. Uses Node.js built-in test runner — no external test dependencies.

## Pay Constants (Kerala Baseline)

| Constant | Value | DB Column |
|---|---|---|
| Base rate | ₹15 per delivery | `base_rate` |
| Per km rate | ₹6/km | `per_km_rate` |
| Surge bonus | ₹20 (flat) | `surge_bonus` |
| Wait threshold | 10 minutes | `wait_threshold_mins` |
| Wait compensation | ₹10 (flat) | `wait_compensation` |
| Minimum wage floor | ₹70/hr | `min_wage_per_hour` |

All constants are admin-configurable via `PUT /api/admin/pay-config`.

## Branch Strategy

| Branch | Purpose | Status |
|---|---|---|
| `main` | Stable, merged code | ✓ Active |
| `core/pay-engine` | Pay Engine Express server + MySQL | ✓ Active |
| `core/auth` | Auth module — JWT, roles (Harikrishnan) | Scaffold |
| `core/admin-panel` | Admin Panel API + Flutter screen | Planned |
| `core/rider-dashboard` | Rider Dashboard + earnings chart | Planned |

## References

- Fairwork India Ratings 2024 — IIIT Bangalore / Oxford
- Nair et al., IJCAI 2022 — "Gigs with Guarantees: Achieving Fair Wage for Food Delivery Workers"
- Rajasthan Platform Based Gig Workers Act, 2023
- Human Rights Watch, "The Gig Trap," 2025
- NITI Aayog — India gig workforce 7.7M (2023), projected 23.5M by 2030
