# Payments Proto

Shared gRPC protocol definitions for The Last Viking's online payment system.

This repository contains the public `.proto` contracts used between:

* The **Payment Service** (central payment + entitlement authority)
* Product backends (e.g. NextApp, Sentinelix, NSBlast, etc.)
* Optional notification callbacks implemented by product backends

The goal is:

* Stable, minimal, privacy-preserving contracts
* Clear idempotency rules
* Safe at-least-once delivery semantics
* Support for multiple independent products using one payment backend

---

# Architecture Overview

```
Product Backend  --->  PaymentsService  --->  Stripe / Google Play
        ^                    |
        |                    v
        +---- BackendNotifications (best effort)
```

## Responsibilities

### Payment Service

* Processes Stripe webhooks
* Processes Google Play RTDN
* Normalizes provider state into internal `Entitlement`
* Exposes authoritative entitlement state via gRPC
* Optionally notifies backends of entitlement changes

### Product Backends

* Call `GetEntitlement` before delivering paid features
* Initiate subscription flows via `CreateSubscriptionIntent`
* Implement `BackendNotifications` for faster UX (optional)
* Must be idempotent

---

# Stability Guarantees

This repository follows semantic versioning.

* `payments.v1` is considered stable once released.
* Backward-compatible field additions may occur.
* Fields will not be removed or repurposed within the same major version.
* Enum values may be extended; clients must handle unknown values gracefully.

---

# Security Model

All RPC communication is expected to run:

* Over VPN/private network
* With mutual TLS (mTLS)
* With service identity derived from certificate SAN

Authorization is handled by the Payment Service based on service identity.

Public internet exposure should be limited to webhook HTTP endpoints only (not gRPC).

---

# Entitlement Model

`Entitlement` is the authoritative state used by all product backends.

Key properties:

* `tenant_id` – opaque identifier
* `product_id` – identifies which product the entitlement applies to
* `plan_id` – product-specific plan
* `state` – current entitlement state
* `valid_until` – end of paid period (if applicable)
* `version` – monotonic counter (critical for ordering & idempotency)

## Version Semantics

`version` increments every time the entitlement changes.

Backends MUST:

* Treat higher `version` as newer
* Ignore notifications with lower `version`
* Use `version` for idempotency and ordering

This eliminates the need for streaming synchronization.

---

# Delivery Guarantees

## PaymentsService (backend → payment)

Calls are standard unary RPC.

Clients should:

* Use deadlines/timeouts
* Retry safely where appropriate
* Treat responses as authoritative

## BackendNotifications (payment → backend)

Delivery is **at-least-once**.

This means:

* Notifications may be retried
* Notifications may arrive more than once
* Order is not guaranteed across different tenants

Backends MUST:

* De-duplicate using `event_id`
* Enforce monotonic `entitlement.version`
* Be idempotent

If a notification fails permanently, correctness is still preserved because:

* Product backends can always call `GetEntitlement`
* Entitlement reads are authoritative

Notifications exist for UX acceleration only.

---

# Correctness Guarantees

The system is designed so that:

* A successful payment will eventually result in an ACTIVE entitlement
* If webhook delivery is delayed, reconciliation jobs will converge state
* Entitlement reads are the single source of truth
* Push notifications are never required for correctness

The system prioritizes:

> "Never get paid and fail to deliver goods."

---

# Multi-Product Support

The payment backend supports multiple independent products.

`product_id` disambiguates entitlements.

Examples:

* `nextapp`
* `sentinelix`
* `nsblast`
* `lgxpro`

Products share:

* The same Payment Service
* The same Stripe account (with different price IDs)
* The same Google Play backend (different package names if needed)

But maintain separate entitlements.

---

# Provider Mapping

The Payment Service internally maps:

Stripe / Google Play state → `EntitlementState`

Backends must not assume provider-specific semantics.
Always rely on the normalized `EntitlementState`.

---

# Idempotency Rules

## Client → Payment Service

Clients may include `client_reference_id` to correlate retries.

Payment Service must treat duplicate confirmations safely.

## Payment Service → Backend

Backends must de-duplicate using:

* `event_id`
* `entitlement.version`

If the same version is applied twice, it must be safe.

---

# Recommended Build Tooling

We recommend using `buf` for linting and generation.

## Validate Protos Manually

```bash
./scripts/validate-protos.sh
```

Example `buf.yaml`:

```yaml
version: v1
lint:
  use:
    - DEFAULT
breaking:
  use:
    - FILE
```

Example generation:

```bash
buf generate
```

Rust users (tonic):

```bash
tonic-build
```

---

# Design Philosophy

This protocol intentionally:

* Avoids streaming
* Avoids cross-service state coordination
* Avoids provider leakage
* Minimizes required fields
* Favors monotonic versioning over complex ordering

It is optimized for:

* Small HA clusters
* A few thousand tenants
* Strong correctness guarantees
* Operational simplicity

---

# License

Apache-2.0
