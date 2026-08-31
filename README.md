# FairDrop

A policy demonstration prototype for algorithmically fair gig delivery pay.

## Problem

Gig delivery platforms in India use threshold-based ("cliff") incentive structures and opaque algorithmic management. Workers are forced into 10–12 hour workdays, penalized for factors outside their control, and assigned geographically unfair orders. No platform in India currently scores above 6/10 on Fairwork India's five-principle evaluation (Fairwork India Ratings 2024).

FairDrop proposes and implements transparent, worker-fair pay policies that remain operationally viable for the platform.

## What FairDrop Addresses

- **Incentive trap** — Cliff bonus replaced with linear per-delivery pay
- **Out-of-zone assignment** — Dynamic zone reassignment with a configurable radius cap
- **Delay penalties** — Delay context flags with verification architecture (mocked in prototype)
- **Pay opacity** — Formula published to rider before acceptance; line-by-line breakdown after delivery
- **Restaurant wait time** — Configurable wait compensation threshold *(partial)*
- **Minimum earnings floor** — Configurable floor aligned with Kerala minimum wage *(partial)*

## What FairDrop Does Not Address

- Real GPS tracking
- Real payment gateway
- Mobile application
- Live Traffic / Railway API calls (documented as production architecture; prototype uses mock flags)
- Union recognition or collective bargaining

## Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| Pay Engine | Node.js + Express + MySQL | Pay data is relational — deliveries, riders, configs, earnings require joins and audit trails |
| Auth + Order Flow | Node.js + Express + MongoDB | Auth/Order data is document-shaped — flexible schema, nested objects |
| Frontend | React | — |

## Project Structure

```
fairdrop/
├── pay-engine/
│   ├── src/payEngine.js        # Core pay calculation logic
│   ├── tests/payEngine.test.js # Unit tests
│   └── config/constants.js     # Configurable pay constants (Kerala baseline)
├── database/
│   ├── mysql/schema.sql        # Pay Engine tables
│   └── mongodb/collections.md  # Auth/Order collection design
└── docs/
    └── api-contract.md         # POST /api/pay/calculate spec
```

## Running the Tests

```bash
node --test pay-engine/tests/payEngine.test.js
```

No external test dependencies — uses Node.js built-in test runner.

## Pay Constants (Kerala Baseline)

| Constant | Value |
|---|---|
| Base rate | ₹15 per delivery |
| Per km rate | ₹6/km |
| Surge bonus | ₹20 (flat) |
| Wait threshold | 10 minutes |
| Wait compensation | ₹10 (flat) |
| Minimum wage floor | ₹70/hr |

All constants are admin-configurable.

## References

- Fairwork India Ratings 2024 — IIIT Bangalore / Oxford
- Nair et al., IJCAI 2022 — "Gigs with Guarantees: Achieving Fair Wage for Food Delivery Workers"
- Rajasthan Platform Based Gig Workers Act, 2023
- Human Rights Watch, "The Gig Trap," 2025
