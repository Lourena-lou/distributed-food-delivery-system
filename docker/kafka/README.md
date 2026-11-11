# Kafka Event Integration

Both database deployment variants include one Apache Kafka 3.9 broker running
in KRaft combined mode. The `kafka-init` job creates every topic before any
Ballerina service starts. Each topic has three partitions and one replica for
the local single-broker environment.

## Topic ownership and consumers

| Topic family | Producer | Consumers | Purpose |
|---|---|---|---|
| `orders.*` | Order Service | Payment, Notification | Order creation and lifecycle updates |
| `payments.*` | Payment Service | Order, Notification | Payment decisions and order confirmation |
| `delivery.*` | Delivery Service | Order, Notification | Driver assignment and delivery completion |

The Order Service consumes `payments.completed`, `delivery.assigned`, and
`delivery.completed` to apply its own authoritative state transitions. The
Payment Service consumes `orders.created` to create a deterministic pending
payment. Notification consumes lifecycle topics in a separate consumer group,
so it receives the same events without competing with workflow consumers.

## Event envelope

Every message contains:

- `eventId`: unique identifier used by idempotent consumers;
- `eventType`: topic-aligned event name;
- `aggregateId`: order identifier and Kafka record key;
- `source`: service that owns the state change;
- `schemaVersion`: currently `1`;
- `occurredAt`: domain occurrence time; and
- `payload`: the complete version-one domain snapshot.

## Verification

From the `docker` directory, after starting either stack:

```powershell
.\scripts\smoke-test.ps1
.\scripts\verify-kafka.ps1 -Backend mongodb
```

Use `-Backend mysql` for the MySQL stack. Kafka is exposed as `localhost:9092`
by default and can be moved with `KAFKA_PORT` in `.env`. Ballerina services use
the internal `kafka:19092` listener.

The local broker uses plaintext transport and a replication factor of one. A
production deployment should use multiple brokers, encrypted authentication,
and a transactional outbox for atomic database-and-event publication.
