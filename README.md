# Distributed Food Delivery Platform

Assignment 2 is implemented as seven independently runnable Ballerina Swan Lake
services. The services provide HTTP APIs, domain validation, lifecycle rules,
interchangeable memory, MongoDB, and MySQL persistence adapters, and Kafka-based
asynchronous workflow coordination. Separate Docker Compose variants are
available for MongoDB and MySQL; both include the same Kafka event topology. A
Ballerina terminal client provides the interactive interface and communicates
with the platform exclusively through those HTTP APIs.

## Services

| Service | Package | Default port | Base path | Responsibility |
|---|---|---:|---|---|
| Customer | `customer_service` | 9101 | `/customers` | Profiles, addresses, order history |
| Restaurant | `restaurant_service` | 9102 | `/restaurants` | Menus, stock, opening hours |
| Order | `order_service` | 9103 | `/orders` | Order aggregate and lifecycle |
| Payment | `payment_service` | 9104 | `/payments` | Simulated payment decisions |
| Delivery | `delivery_service` | 9105 | `/delivery` | Drivers, assignments, delivery status |
| Notification | `notification_service` | 9106 | `/notifications` | Multi-channel alert tracking |
| Admin | `admin_service` | 9107 | `/admin/reports` | Reporting projections and summaries |

Each package contains:

- `types.bal` for domain and HTTP response types;
- a domain-named repository file for deterministic in-memory test storage;
- a domain-named persistence adapter for MongoDB/MySQL dispatch and queries;
- `database_config.bal` for connector and backend configuration;
- `service.bal` for HTTP translation only; and
- focused repository tests under `tests/`.

## Run the complete system with Docker

Docker Compose starts all seven Ballerina services, the selected database,
Kafka, and the one-time Kafka topic initializer. Run either the MongoDB stack or
the MySQL stack, but not both simultaneously because they expose the same ports.

### Prerequisites

- Ballerina Swan Lake `2201.12.9`;
- Docker Desktop with its Linux container engine running; and
- Docker Compose v2 (included with current Docker Desktop releases).

Confirm the required tools from PowerShell:

```powershell
docker version
docker compose version
bal version
```

### First-time setup

From the `assignment-2/docker` directory, create the local environment file and
replace every example password:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\docker
Copy-Item .env.example .env
notepad .env
```

The `.env` file is ignored by Git. MongoDB root credentials initialize the
container, while MongoDB application credentials are used by the services.
MySQL follows the same root/application separation. Kafka uses `KAFKA_PORT`,
which defaults to `9092`.

Build all seven service container images:

```powershell
.\scripts\build-images.ps1
```

Run the image build again after changing Ballerina service code.

### Start the MongoDB variant

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\docker
.\scripts\start-stack.ps1 -Backend mongodb
.\scripts\smoke-test.ps1
.\scripts\verify-kafka.ps1 -Backend mongodb
```

The smoke test waits for all seven HTTP health resources. Kafka verification
confirms that all eleven lifecycle topics exist with three partitions each.

### Start the MySQL variant

Stop the MongoDB variant first if it is running, then start MySQL:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\docker
.\scripts\stop-stack.ps1 -Backend mongodb
.\scripts\start-stack.ps1 -Backend mysql
.\scripts\smoke-test.ps1
.\scripts\verify-kafka.ps1 -Backend mysql

to delete previous volume of data
docker volume rm food-delivery-mysql_mysql-data
```

MongoDB and MySQL have identical service APIs but use separate persistent data
volumes. Records entered in one variant do not appear in the other.

### Run the terminal client

Keep the selected Docker stack running. Open a second PowerShell terminal and
run:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\client\food_delivery_cli
bal run
```

Select `1` first to confirm that the client reports all seven services as `UP`.
The other menus provide the customer, restaurant, order, payment, delivery,
notification, and administration workflows. The client communicates only with
the HTTP services; it never connects directly to a database or Kafka.

### Inspect or troubleshoot the running stack

For MongoDB:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\docker
docker compose --env-file .env -f compose.mongodb.yml ps
docker compose --env-file .env -f compose.mongodb.yml logs -f
```

For MySQL, replace `compose.mongodb.yml` with `compose.mysql.yml`.

MongoDB Compass can inspect the MongoDB variant through `127.0.0.1:27017`.
Use either of these matching credential sets from `.env`:

| Purpose | Username | Password | Authentication database |
|---|---|---|---|
| Browse as administrator | `MONGODB_ROOT_USERNAME` | `MONGODB_ROOT_PASSWORD` | `admin` |
| Browse as the application | `MONGODB_APP_USERNAME` | `MONGODB_APP_PASSWORD` | `food_delivery` |

The project database is named `food_delivery`.

### Stop the system

Use the backend that is currently running:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\docker
.\scripts\stop-stack.ps1 -Backend mongodb
# or
.\scripts\stop-stack.ps1 -Backend mysql
```

Normal shutdown removes the containers and network but preserves the selected
database and Kafka named volumes.

## Kafka coordination mode

Kafka is included in both Compose variants as `apache/kafka:3.9.2`. ZooKeeper is
not included and is not required. Kafka runs in KRaft mode, with the single
Kafka container performing both `broker` and `controller` roles. The
`kafka-init` container waits for Kafka to become healthy, creates the eleven
assignment topics, and then exits successfully. Internal services connect to
`kafka:19092`; host tools can connect through `localhost:9092` by default.

## Run a service directly without Docker

From one of the package directories:

```powershell
bal run
```

Override the default listener port when needed:

```powershell
bal run -CservicePort=9203
```

## Verify all packages

Run `bal test` from each directory under `services/`. Every package targets the
locally installed Ballerina `2201.12.9` distribution.

## Order lifecycle

The Order Service enforces this state machine atomically:

```text
CREATED -> CONFIRMED -> PREPARING -> READY -> OUT_FOR_DELIVERY -> DELIVERED
    |          |            |
    +----------+------------+----> CANCELLED
```

Cancellation is intentionally rejected after an order becomes `READY`, because
food and dispatch resources have already been committed by that stage.

Kafka coordinates the cross-service steps. Creating an order produces
`orders.created`, which creates a pending payment. A successful payment advances
the order to `CONFIRMED`; driver assignment advances a ready order to
`OUT_FOR_DELIVERY`; and delivery completion advances it to `DELIVERED`.
Notification consumes the user-facing lifecycle topics independently.

## Persistence boundary

Set `databaseBackend` to `memory`, `mongodb`, or `mysql`. The service layer calls
one persistence contract, while the adapter dispatches to the selected backend.
MongoDB stores service-owned aggregates as documents; MySQL stores the same
domain data in normalized tables. Public HTTP APIs are identical for both.

See [`database/README.md`](database/README.md) for initialization and
configuration instructions, [`docker/README.md`](docker/README.md) for the two
containerized deployment variants, and [`docker/kafka/README.md`](docker/kafka/README.md)
for the event contract and topic map.
