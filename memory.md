# Memory — Assignment 2 Distributed Food Delivery Platform

Last updated: 2026-08-24 10:49:22 +02:00

## What was built

- The Assignment 2 project is located at
  `C:\Users\chilw\Documents\ballerina\assignment-2`.
- It contains seven independently packaged Ballerina services: Customer,
  Restaurant, Order, Payment, Delivery, Notification, and Admin.
- The project supports memory repositories for tests plus complete MongoDB and
  MySQL deployment variants.
- Docker Compose starts the seven services, the selected database, Kafka in
  KRaft mode, and a topic-initialization container.
- A separate Ballerina terminal client is available at
  `client/food_delivery_cli`; it communicates only with the service HTTP APIs.
- `STUDENT_GUIDE.md` was created as a separate beginner-focused guide. It has
  23 sections covering architecture, service functions, event flows,
  persistence, Docker, startup, testing, troubleshooting, design decisions,
  and presentation questions. The original `README.md` was not replaced.

## Decisions made

- Keep each business capability in its own Ballerina package, image, port, and
  persistence boundary.
- Use REST for direct commands and queries, and Kafka for asynchronous
  lifecycle events.
- Keep the Order Service as the single authority for order-state transitions.
- Use repository contracts with memory, MongoDB, and MySQL adapters so the
  service APIs and terminal client do not change when the backend changes.
- Run one database compose variant at a time because both variants publish the
  same application ports.
- Use Kafka KRaft mode; ZooKeeper is intentionally not part of this deployment.
- Keep the terminal client separate from the services and prohibit direct
  client access to Kafka or the databases.
- Preserve the concise root README and maintain the deeper teaching material in
  `STUDENT_GUIDE.md`.

## Problems solved

- Windows WSL/virtualization support was enabled so Docker Desktop could run
  Linux containers.
- MongoDB Compass authentication was resolved by matching the application user
  with the application authentication database. No credentials are stored in
  this memory.
- Documented that credentials in an initialized database volume do not change
  merely because `docker/.env` changes.
- Documented the MySQL port-collision workaround: publish a different host port
  while containers continue using MySQL's internal port 3306.
- Clarified that normal Docker shutdown preserves database data in named
  volumes, while explicit volume removal is destructive.
- Clarified that the Ballerina services already run inside Docker containers;
  separate host-side `bal run` commands are not required for them.

## Current state

- The implementation and both Docker deployment variants are present.
- Helper scripts exist to build images, start/stop a selected backend, smoke
  test all seven health endpoints, and verify all eleven Kafka topics.
- The terminal client and service unit tests are present.
- `STUDENT_GUIDE.md` was checked for balanced Markdown fences, all 23 table-of-
  contents targets, accurate script/compose names, and accidental credentials.
- Whether any containers are currently running is unknown; inspect Docker state
  before starting another stack.

## Next session starts with

1. Run `/remember restore` and confirm this handoff.
2. Read `STUDENT_GUIDE.md` for the complete operating procedure.
3. Inspect Docker with `docker compose ps`, then start exactly one backend if a
   live demonstration or end-to-end verification is needed.
4. Use the guide's smoke test, Kafka verification, and complete order-lifecycle
   walkthrough to validate the selected backend.

## Open questions

- No implementation change is currently pending. The next task depends on
  whether the user wants a live end-to-end test, further teaching material, or
  another project enhancement.
