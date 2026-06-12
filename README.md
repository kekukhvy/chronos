# Chronos

> Universal event scheduler for microservice systems

## Vision

Chronos is a centralized scheduling platform for microservice architectures.

Instead of embedding Quartz in every service, writing custom `@Scheduled` tasks, or building delayed queues — services use a single Chronos API.

Chronos does not execute business logic.  
Chronos is responsible only for:

```
Store → Wait → Trigger → Retry → Track
```

---

## The Problem

In large microservice systems, scheduling becomes a mess:

- Every service contains its own Quartz instance
- Every service requires separate configuration
- Every service stores its own jobs
- No centralized schedule management
- No unified execution history
- Hard to reuse across projects

Chronos solves this through centralized scheduling.

---

## How It Works

A booking service wants to cancel a reservation after 15 minutes.

Instead of:
```java
@Scheduled
public void expireBooking() { ... }
```

It creates a task in Chronos:
```json
{
  "name": "expire-booking",
  "runAt": "2026-06-15T10:00:00Z",
  "destinationId": "booking-kafka",
  "messageType": "booking.expire.v1",
  "payload": {
    "bookingId": "123"
  }
}
```

After 15 minutes, Chronos delivers the message to the destination.  
The booking service receives the event and executes its business logic.

---

## Core Concepts

### Schedule
Defines **when** to execute:
```json
{ "runAt": "2026-06-15T10:00:00Z" }
```
or
```json
{ "cron": "0 */5 * * * *", "timezone": "Europe/Vienna" }
```

### Destination
Defines **where** to deliver:
```json
{ "id": "booking-kafka", "type": "KAFKA" }
```

Supported types: `KAFKA` · `SQS` · `WEBHOOK` · `RABBITMQ`

### Message
Defines **what** to send:
```json
{
  "messageType": "booking.expire.v1",
  "payload": { "bookingId": "123" }
}
```

### Execution
Tracks the result: `SUCCESS` · `FAILED` · `RETRYING` · `DEAD_LETTER`

---

## Architecture

```
+------------------+
| Client Services  |
+---------+--------+
          |
          v
+------------------+
|   Chronos API    |   REST API — manage schedules
+---------+--------+
          |
          v
+------------------+
|    PostgreSQL    |   Store tasks and execution history
+---------+--------+
          |
          v
+------------------+
| Scheduler Engine |   Find due jobs, claim, retry
+---------+--------+
          |
          v
+------------------+
| Delivery Adapter |   Send to destination
+---------+--------+
          |
          v
+------------------+
| Kafka/SQS/etc    |
+------------------+
```

---

## Project Structure

```
chronos/
├── chronos-api/            # REST API
├── chronos-engine/         # Scheduler engine (claim, retry, cron)
├── chronos-worker/         # Delivery workers
├── chronos-adapters/       # Pluggable delivery adapters
│   ├── kafka/
│   ├── sqs/
│   ├── webhook/
│   └── rabbitmq/
├── chronos-admin/          # Admin UI (Vaadin)
├── chronos-sdk/            # Java SDK for clients
└── common/                 # Shared models, API contracts
```

---

## Tech Stack

- **Java 26** — pure Java, no Spring (except Admin UI)
- **JOOQ** — type-safe SQL
- **Flyway** — database migrations
- **HikariCP** — connection pooling
- **Kafka** — event delivery adapter
- **SLF4J + Logback** — logging
- **Vaadin + Spring** — Admin UI
- **Docker Compose** — local development
- **Gradle multi-project** — mono repo

---

## Retry Strategy

```
Attempt 1
↓ 5 sec
Attempt 2
↓ 30 sec
Attempt 3
↓ Dead Letter
```

Configurable per schedule.

---

## Roadmap

### V1 — MVP
- [ ] Create / Get / Delete schedule
- [ ] One-time execution (`runAt`)
- [ ] Kafka adapter
- [ ] Retry with backoff
- [ ] Execution history
- [ ] Docker Compose

### V2 — Reliability
- [ ] Cron jobs
- [ ] Timezones
- [ ] Pause / Resume
- [ ] Dead Letter Queue

### V3 — Adapters
- [ ] SQS Adapter
- [ ] RabbitMQ Adapter
- [ ] Webhook Adapter

### V4 — Multi-tenancy
- [ ] API Keys
- [ ] Tenant isolation
- [ ] RBAC
- [ ] Credentials per tenant

### V5 — Observability
- [ ] Admin UI (Vaadin)
- [ ] Metrics
- [ ] Prometheus + Grafana

---

## Why Not Temporal?

Temporal is a **Workflow Engine** — it manages complex multi-step business processes.

Chronos is a **Scheduler** — it is responsible only for triggering events at the right time.

---

## Development Conventions

### Architecture
- DDD + Hexagonal Architecture (Ports & Adapters)
- `domain` layer — zero framework dependencies, pure Java
- `application` layer — orchestrates domain, no HTTP/Kafka knowledge
- `infrastructure` layer — implements ports (repositories, messaging)

### Git Workflow
- `main` — stable
- `develop` — default development branch
- `feature/xxx` — one branch per feature, from develop
- Every feature = Issue → branch → PR → merge to develop

### Code Style
- No Lombok in domain layer
- Constants over string literals
- Configuration via `.properties` files
- Docker Compose for all infrastructure

### Key Engine Pattern — Claim
```sql
SELECT * FROM schedules
WHERE status = 'PENDING'
  AND run_at <= NOW()
  AND tenant_id = ?
FOR UPDATE SKIP LOCKED
LIMIT 10
```

This prevents two workers from picking the same job — the core concurrency challenge.

---

## Repository
https://github.com/kekukhvy/chronos
