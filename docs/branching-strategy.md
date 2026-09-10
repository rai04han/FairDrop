# FairDrop — Branching Strategy

**Convention:** Branch names follow `{type}/{module}` pattern.

## Branch Map

| Branch | Type | Module | Owner | PRD Features | Timeline |
|---|---|---|---|---|---|
| `main` | stable | — | Shared | Merged, tested code only | Ongoing |
| `core/pay-engine` | feature | Pay Engine | Raihan | F-PAY-01 to F-PAY-05, F-ADMIN-01 | Week 7 |
| `core/auth` | feature | Auth | Harikrishnan | F-AUTH-01 | Week 7 |
| `core/admin-panel` | feature | Admin Panel | Raihan | F-ADMIN-01 (Flutter) | Week 8 |
| `core/rider-dashboard` | feature | Rider Dashboard | Raihan | F-DASH-01, F-DASH-02 | Week 11 |
| `flutter/pay-breakdown` | feature | Flutter | Raihan | F-DASH-01 (Pay Breakdown screen) | Week 9 |
| `flutter/rider-dashboard` | feature | Flutter | Raihan | F-DASH-02 (Earnings chart) | Week 11 |
| `flutter/admin-panel` | feature | Flutter | Raihan | F-ADMIN-01 (Admin Panel screen) | Week 12 |

## Merge Flow

```
feature branch → main (via Pull Request)
```

1. All development happens on feature branches
2. Feature branch is pushed to `origin`
3. Pull Request opened on GitHub
4. Code reviewed (self-review for solo work, cross-review for shared modules)
5. Merged into `main` after verification
6. Feature branch retained for history

## Commit Message Convention

Format: `type(scope): description`

| Type | When to use |
|---|---|
| `feat` | New feature or functionality |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `chore` | Project setup, tooling, dependencies |
| `test` | Adding or modifying tests |
| `refactor` | Code restructuring without behavior change |

**Scope** is the module name: `pay-service`, `auth`, `order-flow`, `zone`, `flutter`.

Examples:
- `feat(pay-service): add pay calculation routes with MySQL persistence`
- `fix(pay-service): handle divide-by-zero in floor top-up`
- `docs: update README with setup instructions`
- `chore(pay-service): add package.json with Express and mysql2 dependencies`

## Database Ownership

Each person owns their database end-to-end. No cross-database access.

| Database | Technology | Owner | Modules |
|---|---|---|---|
| `fairdrop_pay` | MySQL | Raihan | Pay Engine, Admin Config, Rider Dashboard |
| MongoDB | MongoDB | Harikrishnan | Auth, Order Flow, Zone Assignment |

Cross-module data flows only through the defined HTTP API contract (`docs/api-contract.md`).
