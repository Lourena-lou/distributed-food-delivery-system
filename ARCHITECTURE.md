# Architecture Decisions

## Independent service packages

Every microservice is a separate Ballerina package and process. It owns its
listener, state, validation, and tests. No service reads another service's
repository directly.

## Single data owner

- Customer Service owns customer profiles, addresses, and order references.
- Restaurant Service owns menus, hours, and inventory.
- Order Service owns the authoritative order state.
- Payment Service owns payment attempts and decisions.
- Delivery Service owns drivers and delivery assignments.
- Notification Service owns notification delivery records.
- Admin Service owns reporting projections, not operational records.

## Concurrency

Mutable in-memory test state is declared `isolated` and accessed inside `lock`
statements. Values are cloned at repository boundaries so callers cannot mutate
protected state. Database adapters use guarded updates and MySQL transactions
for lifecycle transitions and multi-record operations such as driver
reservation plus assignment creation.

## Database strategy

MongoDB and MySQL are implemented as alternative persistence adapters behind
the same domain functions. The configured backend is chosen at service startup,
so it cannot drift during a request. MongoDB keeps aggregates together as
documents. MySQL normalizes nested data and uses transactions where one domain
operation changes multiple rows. Both preserve the same domain behavior and
HTTP contracts.

Tables and collections are service-owned even when the development deployment
uses one physical database instance. Cross-service foreign keys are avoided so
the database does not become an implicit integration layer. Kafka events will
be the integration mechanism between services.

## Container strategy

Every service is built as its own image using Ballerina Code-to-Cloud. The
MongoDB and MySQL Compose variants share the same seven service images and API
ports; only their database configuration differs. The variants run separately
to avoid duplicate service containers and port collisions. Database health
checks gate service startup, named volumes preserve data, and initialization
scripts establish schemas, validators, indexes, and least-privilege users.

## Event strategy

Kafka coordinates cross-service workflows without sharing service databases:

```text
orders.created -> pending payment creation -> payments.completed
payments.completed -> orders.confirmed
orders.ready -> delivery assignment -> delivery.assigned
delivery.completed -> orders.delivered
user-facing lifecycle events -> notifications
```

Event payloads include stable aggregate identifiers, unique event identifiers,
occurrence time, source service, and schema version. Producers request all
in-sync replica acknowledgements and enable Kafka idempotence. Records use the
order identifier as their key, which preserves per-order ordering. Consumer
groups commit offsets only after successful processing, while deterministic
payment and notification identifiers make retries safe.
