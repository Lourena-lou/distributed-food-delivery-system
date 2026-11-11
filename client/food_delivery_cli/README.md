# Food Delivery Terminal Client

This Ballerina terminal application is the platform's interactive user
interface. It communicates only with the seven REST services. It never connects
directly to MongoDB, MySQL, or Kafka; those infrastructure concerns remain
behind the service boundary.

## Start the platform

Start either database variant from `assignment-2/docker`:

```powershell
.\scripts\start-stack.ps1 -Backend mongodb
# or
.\scripts\start-stack.ps1 -Backend mysql
```

Only one variant should run at a time because both expose the same service
ports.

## Run the client

From this directory:

```powershell
bal run
```

The main menu provides service health, customer, restaurant, order, payment,
delivery, notification, and administration workflows. Successfully used IDs are
remembered for the current session and offered as defaults in later prompts.

## Configure service URLs

The defaults target `localhost` ports `9101` through `9107`. To override them,
copy `Config.toml.example` to `Config.toml`, then edit the required URLs.
`Config.toml` is intentionally ignored because local configuration can contain
environment-specific values.

## Build without running

```powershell
bal build
```

The executable JAR is generated at `target/bin/food_delivery_cli.jar`.
