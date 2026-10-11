# FairDrop Flutter App — Product Requirements Document

**Version:** 1.0
**Platform:** Flutter/Dart, Android (demo target)
**Project:** MCA Mini Project, TKM College of Engineering, Kollam
**Visual design:** see `Design.md` (separate document)

**Ownership**

| Area | Owner |
|---|---|
| Login, Home, Order Acceptance, Active Delivery, Zone Map | Hari |
| Delivery Summary, Rider Dashboard, Analytics, Admin Pay Config | Raihan |
| App shell, navigation, API clients, Provider setup | Shared |

---

## 1. Overview

The FairDrop app is the mobile interface of a gig-delivery platform designed around transparent, worker-fair pay. Riders see how their pay is calculated before they accept an order, how each delivery was paid afterwards, and whether the platform is meeting a minimum earnings floor. Admins edit the pay configuration under a 7-day advance-notice rule.

The app does not stand alone. It makes the backend's fairness policies visible and verifiable. If a policy isn't shown in the UI, an examiner can't see it.

## 2. Goals and Non-Goals

**Goals**

- G1. Show the pay formula and an estimate before the rider accepts an order (Problem 4).
- G2. Show a line-by-line pay breakdown after every delivery (Problem 4).
- G3. Show zone assignment, zone changes after out-of-zone deliveries, and the out-of-zone cap (Problem 2).
- G4. Show delay flags and whether each was verified (Problem 3).
- G5. Show hourly earnings against the minimum wage floor (Problems 1 and 6, partial).
- G6. Show a FairDrop-vs-cliff-bonus comparison for the same rider (the core academic contribution).
- G7. Let an admin change pay constants with mandatory notice and a recorded reason.
- G8. Complete an end-to-end demo flow with no manual database edits.

**Non-goals (deliberate decisions)**

- Real-time GPS tracking, payment gateway, websockets, background idle timers, app store release, union recognition.
- Customer and restaurant screens. Those roles are exercised through Postman or a seed script.
- Localization (Malayalam) and iOS builds.

## 3. Users and Roles

| Role | In the app | Notes |
|---|---|---|
| Rider | Yes, primary | All rider screens |
| Admin | Yes | Pay config screens only |
| Customer | No | Backend role only; places orders via Postman |
| Restaurant | No | Backend role only; marks orders ready via Postman |

The backend auth module keeps all four roles (`customer`, `rider`, `restaurant`, `admin`), because order placement and pickup readiness depend on them. The app supports only `rider` and `admin`.

- After login the app reads the role from the token and routes to the matching shell: rider shell or admin shell.
- A customer or restaurant account that logs in sees a "This role isn't supported in the mobile app" screen with a logout button. No session is kept.

## 4. Screen Inventory and Priority

| # | Screen | Role | Owner | Priority |
|---|---|---|---|---|
| 1 | Splash | All | Shared | P0 |
| 2 | Login | All | Hari | P0 |
| 3 | Home (online toggle, incoming order) | Rider | Hari | P0 |
| 4 | Order Acceptance (formula + estimate) | Rider | Hari | P0 |
| 5 | Active Delivery (status steps) | Rider | Hari | P0 |
| 6 | Delivery Summary (pay breakdown) | Rider | Raihan | P0 |
| 7 | Zone Map | Rider | Hari | P0 |
| 8 | Rider Dashboard | Rider | Raihan | P0 |
| 9 | Analytics (FairDrop vs cliff) | Rider | Raihan | P0 |
| 10 | Admin: Pay Config (active, history, new) | Admin | Raihan | P1 |
| 11 | Onboarding (policy + safety checklist) | Rider | Shared | P1 |
| 12 | Profile | Rider | Hari | P1 |
| 13 | Grievance / feedback form | Rider | Shared | P2 |

Onboarding is P1 but carries two Fairwork principles (safety onboarding, transparent policy at signup). Build it before Profile.

## 5. Functional Requirements

### 5.1 Splash and Login (P0)

- FR-1. Splash checks for a stored JWT. A valid token routes by role; otherwise to Login.
- FR-2. Login takes email and password and calls the core-service auth endpoint.
- FR-3. On success the JWT and role are stored in secure storage.
- FR-4. A 401 or expired token anywhere in the app clears the session and returns to Login.
- FR-5. Errors show inline messages (invalid credentials, network unreachable). No raw exception text.
- FR-6. Role routing follows Section 3.

### 5.2 Home (P0)

- FR-7. An Online/Offline toggle is the sole source of active-hours accounting. The app sends the state change to core-service, which records timestamps and derives `active_hours_today`. The app never computes hours itself.
- FR-8. When online, the app polls for an assigned order at a configurable interval (default 10 seconds). No websockets.
- FR-9. Shows the current zone name, today's earnings so far, and an hourly-earnings-vs-floor indicator.
- FR-10. An incoming assigned order opens Order Acceptance.

### 5.3 Order Acceptance (P0)

- FR-11. Shows restaurant, drop-off area, and distance in km.
- FR-12. Shows the pay formula using the live constants: base + (distance × per-km rate) + surge (if active) + wait compensation (if restaurant wait exceeds the threshold).
- FR-13. Shows an estimated pay covering base, distance and surge only. A visible note says wait compensation and floor top-up are calculated after delivery. The estimate is never presented as final.
- FR-14. If the order is out of zone, shows an out-of-zone badge, the distance beyond the zone boundary, and a plain-language statement of the consent rule.
- FR-15. Accept and Decline buttons. Declining shows no penalty language anywhere. A declined order is released for reassignment by core-service.
- FR-16. If the constants can't be loaded, Accept is disabled with an explanation. A rider is never asked to accept without seeing the formula.

### 5.4 Active Delivery (P0)

- FR-17. Linear status steps: Assigned → Arrived at Restaurant → Picked Up → Delivered.
- FR-18. "Arrived at Restaurant" and "Picked Up" send timestamps. Restaurant wait is the difference, computed server-side. No background timer.
- FR-19. Optional "Report a delay" action with type (traffic / restaurant / railway). The app displays verification state (`verified`, `source`) as returned by the backend. A rider cannot self-verify.
- FR-20. "Delivered" triggers pay calculation on the backend. The app shows a loading state, then navigates to Delivery Summary.

### 5.5 Delivery Summary (P0)

- FR-21. Line-by-line breakdown from the pay response: `base_rate`, `distance_pay`, `surge_bonus`, `wait_compensation`, `total_delivery_pay`, `floor_topup`, `hourly_earnings_so_far`.
- FR-22. Zero-value lines (e.g. surge on a non-surge order) are shown as ₹0 with a one-line reason, not hidden.
- FR-23. All money is formatted with ₹ and two decimals.
- FR-24. If the pay call failed, shows "Pay calculation pending" with Retry. It never shows a fabricated total.
- FR-25. If the delivery had a delay flag, the verified state is shown next to the breakdown.

### 5.6 Zone Map (P0)

- FR-26. Renders the rider's current zone polygon and the other Kollam zones using `flutter_map`.
- FR-27. Shows the current zone and, after an out-of-zone delivery, the new zone with a short notice.
- FR-28. GeoJSON arrives as `[longitude, latitude]`. Conversion to the map library's `LatLng(lat, lng)` happens in one parsing function with a unit test.
- FR-29. No live rider location. Any marker shown is the last delivery endpoint.

### 5.7 Rider Dashboard (P0)

- FR-30. Today's summary: deliveries, total earned, active hours, hourly earnings.
- FR-31. Per-delivery list. Each row expands to the same breakdown as FR-21.
- FR-32. Minimum wage floor status: hourly earnings against the floor value, and the day's top-up total.
- FR-33. Refresh is pull-to-refresh plus automatic refresh when returning from Delivery Summary. "Real-time" means current at refresh, not pushed.

### 5.8 Analytics (P0)

- FR-34. Compares FairDrop earnings against a cliff-bonus model over the same deliveries, using `fl_chart`.
- FR-35. States the cliff-model assumptions on screen (threshold, bonus amount) so the comparison can be challenged.
- FR-36. Includes a case where the cliff model wins, such as a rider who clears the threshold. A comparison where FairDrop always wins by construction fails the balanced-framing criterion.

### 5.9 Admin: Pay Config (P1)

- FR-37. Admin shell is separate from the rider shell and shows only config screens.
- FR-38. Shows the active config: base rate, per-km rate, surge bonus, wait threshold (minutes), wait compensation, minimum wage per hour, and effective-from date.
- FR-39. Shows config history (newest first) with effective-from date, created-by and change reason. History is read-only.
- FR-40. "New config" form with the six constants pre-filled from the active config.
- FR-41. Effective-from date picker cannot select earlier than today + 7 days.
- FR-42. Change reason is mandatory and non-empty.
- FR-43. Client-side validation: numeric fields non-negative; wait threshold is a whole number. Server validation is authoritative and its errors are displayed.
- FR-44. Before submitting, a confirmation dialog shows old → new values for every changed field and the effective date.
- FR-45. Existing configs cannot be edited or deleted from the app.

### 5.10 Onboarding and Profile (P1)

- FR-46. Onboarding shows the pay policy, the 7-day notice commitment and a safety checklist. Acknowledging the checklist sets `safety_checklist_acknowledged`.
- FR-47. Profile shows name, zone, vehicle type, and a link back to the policy summary.
- FR-48. If a scheduled config exists with a future effective date, riders see an "Upcoming pay change" notice on Home or Profile, showing the new values and the effective date. This is what makes the 7-day notice visible on the rider side.
- FR-49. Deactivation-reason display is documented only unless time remains.

### 5.11 Grievance Form (P2)

- FR-50. A single text form posting to core-service. Build only if all P0 and P1 items are done. Otherwise it stays "Designed" in the Fairwork table.

## 6. Backend Dependencies

| Need | Provider |
|---|---|
| Auth: login, token, role | core-service (port 3003) |
| Online/Offline toggle with session timestamps; derived `active_hours_today` | core-service |
| Poll assigned order; accept / decline | core-service |
| Status transitions with timestamps (arrived, picked up, delivered) | core-service |
| Zone data and current-zone lookup | core-service |
| Delay report submission and `delay_context` on the order | core-service |
| Active pay constants (and any scheduled config) for display, read-only, any authenticated user | pay-service (port 3004) |
| Dashboard summary and per-delivery history | pay-service |
| Analytics comparison data | pay-service |
| Pay config list and create, admin role only; enforces effective-from ≥ today + 7 days and mandatory change reason | pay-service |
| JWT verification on all pay-service routes (shared `JWT_SECRET`), plus role check on admin routes | pay-service |
| Rider row creation in MySQL `riders` when a rider account is created | core-service ↔ pay-service |
| Activation of a scheduled config at its effective date, without a background scheduler | pay-service |

**Pay calculation contract (reference, locked):** `POST /api/pay/calculate`, called by core-service on delivery completion.

Request:

```json
{
  "rider_id": "string",
  "order_id": "ORD-{YYYYMMDD}-{4-digit-seq}",
  "distance_km": 0,
  "is_surge_active": false,
  "restaurant_wait_mins": 0,
  "active_hours_today": 0,
  "delay_context": {
    "type": "traffic | restaurant | railway | none",
    "verified": false,
    "source": "system_log | api_mock | none"
  }
}
```

Response:

```json
{
  "order_id": "string",
  "base_rate": 15,
  "distance_pay": 0,
  "surge_bonus": 0,
  "wait_compensation": 0,
  "total_delivery_pay": 0,
  "floor_topup": 0,
  "hourly_earnings_so_far": 0
}
```

**Kerala baseline constants (admin-configurable; the app reads them, never hardcodes them):**

| Constant | Value |
|---|---|
| Base rate | ₹15 per delivery |
| Per-km rate | ₹6/km |
| Surge bonus | ₹20 flat |
| Wait threshold | 10 minutes |
| Wait compensation | ₹10 flat |
| Minimum wage floor | ₹70/hr |

## 7. Architecture

- **State management:** Provider.
- **Layers:** `models/`, `services/` (one API client per backend), `providers/`, `screens/`, `widgets/`.
- **Two base URLs:** core-service (3003) and pay-service (3004), both in a single config file. The Android emulator reaches the host machine at `10.0.2.2`; a physical device needs the LAN IP.
- **Storage:** JWT in `flutter_secure_storage`.
- **Charts:** `fl_chart`. **Maps:** `flutter_map` (no API key).
- **HTTP:** one HTTP package used consistently across both clients.
- **Navigation:** role-based shell chosen after login (rider shell, admin shell).
- **Testing:** Node built-in test runner for backends; Flutter unit tests for the GeoJSON parser, money formatting, and role routing.

## 8. Non-Functional Requirements

- Cold start to Login or Home within 3 seconds on the demo device.
- Every network call has a timeout and a visible error state. No infinite spinners.
- No secrets or backend URLs hardcoded outside the config file.
- The app does no pay arithmetic. Money is displayed as the backend sends it, except the labelled estimate in FR-13.
- Every screen that shows a pay number shows how it was derived, or links to the derivation.

## 9. Fairwork Mapping (UI Evidence)

| Principle | UI evidence | Status |
|---|---|---|
| Fair Pay P1: earnings floor | Dashboard floor status (FR-32) | Implemented |
| Fair Pay P2: living wage | Floor value from config, shown on Dashboard | Implemented |
| Fair Conditions P1: safety onboarding | Onboarding checklist (FR-46) | P1 |
| Fair Conditions P2: downtime compensation | Zone change notice (FR-27); idle logic is backend | Documented |
| Fair Contracts P1: transparent policy | Onboarding and Profile policy view | P1 |
| Fair Contracts P2: 7-day notice and reason | Admin config form (FR-41, FR-42) and rider notice (FR-48) | P1 |
| Fair Management P1: delay challenge | Delay report and verified state (FR-19, FR-25) | Implemented, verification mocked |
| Fair Management P2: grievance | Grievance form (FR-50) | P2 |
| Fair Representation P1: feedback channel | Same form as above | P2 |
| Fair Representation P2: union recognition | None | Out of scope |

"Designed ≥ 8/10" must be presented honestly in the demo: say which principles have working UI, which are documented only, and which depend on P1/P2 work.

## 10. Demo Acceptance Criteria

The demo passes if this sequence works with no manual database edits:

1. Rider logs in and goes online.
2. An order is placed via Postman and appears on Home within the polling interval.
3. Order Acceptance shows the formula and estimate. Rider accepts.
4. Rider steps through arrived, picked up and delivered, with a restaurant wait above the threshold.
5. Delivery Summary shows a breakdown where wait compensation is non-zero and every line matches the pay-service response.
6. Dashboard reflects the new delivery and floor status.
7. Analytics shows the comparison, including a case where the cliff model wins.
8. Zone Map shows the zone change after an out-of-zone delivery.
9. Admin logs in, sees the active config, and creates a new config. A date earlier than 7 days out is rejected; a valid one appears in history with its reason.
10. A customer or restaurant login is refused by the app with the unsupported-role screen.

If UI time runs short on any step, a Postman screenshot of the corresponding API call is sufficient evidence. Steps 3 to 5 are the last to cut.
