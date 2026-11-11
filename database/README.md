# Database Persistence

Every Ballerina service supports the same three persistence modes:

- `memory` for fast unit tests and local API experiments;
- `mongodb` for document persistence; and
- `mysql` for relational persistence.

The selected backend does not change a service's HTTP contract. MongoDB and
MySQL are alternatives: run all services against one MongoDB instance or all
services against one MySQL instance when comparing the two implementations.

## Configure a service

Copy one example into the service package that you want to run:

```powershell
Copy-Item ..\..\database\config\Config.mongodb.toml.example Config.toml
# or
Copy-Item ..\..\database\config\Config.mysql.toml.example Config.toml
```

Replace the example credentials before starting the service with `bal run`.
`Config.toml` is intentionally ignored by Git. For deployed environments,
provide secrets through the platform rather than committing them.

## Initialize MongoDB

Run `mongodb/init/001_collections.js` with `mongosh` against an administrative
connection. The script selects `food_delivery`, creates or updates collection
validators, and creates the required unique and lookup indexes. It is
idempotent and safe to rerun during development.

## Initialize MySQL

Run `mysql/init/001_schema.sql` with a MySQL account that can create databases
and tables. The schema normalizes nested aggregates into child tables and adds
foreign keys, uniqueness rules, and lookup indexes. Create the configured
application user separately and grant it access only to `food_delivery`.

The Docker phase automates both initialization scripts and provides separate
MongoDB and MySQL deployment variants. See [`../docker/README.md`](../docker/README.md)
for image generation, startup, and smoke-test instructions. Repository unit
tests continue to use the deterministic memory backend.
