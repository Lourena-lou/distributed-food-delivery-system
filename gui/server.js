// Serves the browser console and forwards /api/<service>/... to the Ballerina services.
// The services send no CORS headers, so the browser only ever talks to this origin.
// No dependencies: run with `node server.js` (Node 18+).
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const PORT = Number(process.env.GUI_PORT || process.env.PORT || 8088);
const HOST = process.env.SERVICE_HOST || "localhost";
const PUBLIC_DIR = path.join(__dirname, "public");

// Same defaults as client/food_delivery_cli/client_config.bal; override with e.g. ORDER_SERVICE_URL.
const SERVICES = {
  customers: process.env.CUSTOMER_SERVICE_URL || `http://${HOST}:9101`,
  restaurants: process.env.RESTAURANT_SERVICE_URL || `http://${HOST}:9102`,
  orders: process.env.ORDER_SERVICE_URL || `http://${HOST}:9103`,
  payments: process.env.PAYMENT_SERVICE_URL || `http://${HOST}:9104`,
  delivery: process.env.DELIVERY_SERVICE_URL || `http://${HOST}:9105`,
  notifications: process.env.NOTIFICATION_SERVICE_URL || `http://${HOST}:9106`,
  admin: process.env.ADMIN_SERVICE_URL || `http://${HOST}:9107`,
};

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function sendJson(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}

function proxy(req, res, serviceKey, rest) {
  const base = SERVICES[serviceKey];
  if (!base) return sendJson(res, 404, { message: `Unknown service '${serviceKey}'` });
  // /api/admin/... maps to the admin service's /admin/... base path; the others keep their own name.
  const target = new URL(`/${serviceKey}${rest}`, base);
  const upstream = http.request(
    target,
    { method: req.method, headers: { "Content-Type": "application/json", Accept: "application/json" }, timeout: 10000 },
    (up) => {
      res.writeHead(up.statusCode || 502, { "Content-Type": up.headers["content-type"] || "application/json" });
      up.pipe(res);
    },
  );
  upstream.on("timeout", () => upstream.destroy(new Error("timed out after 10s")));
  upstream.on("error", (err) => {
    if (!res.headersSent) sendJson(res, 502, { message: `${serviceKey} service unreachable at ${base} (${err.code || err.message})` });
  });
  req.pipe(upstream);
}

function serveStatic(req, res) {
  const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
  const file = path.normalize(path.join(PUBLIC_DIR, urlPath === "/" ? "index.html" : urlPath));
  if (!file.startsWith(PUBLIC_DIR)) return sendJson(res, 403, { message: "Forbidden" });
  fs.readFile(file, (err, data) => {
    if (err) return sendJson(res, 404, { message: "Not found" });
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream" });
    res.end(data);
  });
}

// Lets the page work even when it is opened from elsewhere (a file:// double-click,
// VS Code Live Server): it then calls this server cross-origin on its own port.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Accept",
};

http
  .createServer((req, res) => {
    const match = req.url.match(/^\/api\/([a-z]+)([/?].*)?$/);
    if (match) {
      for (const [k, v] of Object.entries(CORS)) res.setHeader(k, v);
      if (req.method === "OPTIONS") { res.writeHead(204); return res.end(); }
      // The page pings this to find out whether it is talking to the console server.
      if (match[1] === "console") return sendJson(res, 200, { console: "food-delivery", port: PORT });
      return proxy(req, res, match[1], match[2] || "");
    }
    serveStatic(req, res);
  })
  .on("error", (err) => {
    console.error(err.code === "EADDRINUSE" ? `Port ${PORT} is already in use. Start with another port, e.g. GUI_PORT=8090 node server.js` : err.message);
    process.exit(1);
  })
  .listen(PORT, () => {
    console.log(`Food Delivery console: http://localhost:${PORT}`);
    for (const [name, url] of Object.entries(SERVICES)) console.log(`  /api/${name} -> ${url}`);
  });
