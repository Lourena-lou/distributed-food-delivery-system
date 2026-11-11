# Food Delivery Console (browser GUI)

A browser front end for the seven Ballerina services, built with HTML, Tailwind CSS
(Play CDN) and plain JavaScript. It covers the same workflows as the terminal client
in `client/food_delivery_cli` and, like that client, talks only to the services' HTTP
APIs. It never connects to a database or to Kafka.

## Run it

1. Start a stack (MongoDB or MySQL) as described in the root `README.md`.
2. In a second terminal:

```powershell
cd C:\Users\chilw\Documents\ballerina\assignment-2\gui
node server.js
```

3. Open http://localhost:8088.

Open the console through the server, at http://localhost:8088. The page never talks
to the services itself, so `server.js` must be running. If you open `index.html` some
other way (by double-clicking it, or with VS Code Live Server), it falls back to calling
`server.js` at `http://localhost:8088`. If that server isn't running, every service
shows as unavailable and the page tells you to start it.

Requires Node 18 or newer. No `npm install` step. The page loads Tailwind, the Archivo
and JetBrains Mono fonts, and Lucide icons from CDNs, so the browser needs internet access.

### Why there is a small server

The Ballerina services send no CORS headers, so a page can't call ports 9101–9107
directly. `server.js` serves `public/` and forwards `/api/<service>/...` to each
service:

| Browser path | Forwarded to |
|---|---|
| `/api/customers/...` | `http://localhost:9101/customers/...` |
| `/api/restaurants/...` | `http://localhost:9102/restaurants/...` |
| `/api/orders/...` | `http://localhost:9103/orders/...` |
| `/api/payments/...` | `http://localhost:9104/payments/...` |
| `/api/delivery/...` | `http://localhost:9105/delivery/...` |
| `/api/notifications/...` | `http://localhost:9106/notifications/...` |
| `/api/admin/...` | `http://localhost:9107/admin/...` |

Environment overrides: `GUI_PORT` (default 8088), `SERVICE_HOST` (default
`localhost`), and per-service URLs such as `ORDER_SERVICE_URL`.

## What's in it

- **Overview**: live health of all seven services (rechecked every 15 s), the
  admin platform summary, orders in motion, and how an order moves through the events.
- **Customers**: register, edit profile, add delivery addresses, record orders in history.
- **Restaurants**: register (with optional opening hours), add menu items, update stock.
- **Orders**: filter by customer, restaurant and status, and place orders. The total is
  computed from the menu, and only in-stock items are offered.
- **Waybill** (order detail): the order's lifecycle with its one next step in red, plus
  a tinted copy for each owning service: order (white), restaurant (canary),
  payment (pink), delivery (blue) and notifications (green). Each copy is loaded from
  its own service, so if one service is down only its copy goes blank. The page
  refreshes every 4 s, so Kafka-driven changes such as payment completed → order
  confirmed appear as they happen.
- **Payments**: request payments, then approve or decline them.
- **Delivery**: register drivers, assign available drivers (addresses prefilled), and
  step each delivery through its statuses.
- **Notifications**: queue a notification to a customer, restaurant or driver, and
  record whether it was delivered.
- **Reports**: the platform summary, restaurant statistics and delivery performance,
  plus forms to save those projections.

The console remembers the customer and restaurant you last worked with, like the CLI
session does.
