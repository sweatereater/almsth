import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize, resolve } from "node:path";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const siteRoot = resolve(scriptDir, "..");
const distRoot = resolve(siteRoot, "dist");
const build = spawnSync(process.execPath, [join(scriptDir, "build.mjs")], { stdio: "inherit" });
if (build.status !== 0) process.exit(build.status ?? 1);

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};
const host = "127.0.0.1";
const port = Number.parseInt(process.env.ALMSTH_WIKI_PORT || "4173", 10);

const server = createServer((request, response) => {
  const requestPath = decodeURIComponent((request.url || "/").split("?")[0]);
  const relative = requestPath === "/" ? "index.html" : normalize(requestPath).replace(/^[/\\]+/, "");
  let filePath = resolve(distRoot, relative);
  if (!filePath.startsWith(distRoot) || !existsSync(filePath) || statSync(filePath).isDirectory()) {
    filePath = join(distRoot, "index.html");
  }
  response.writeHead(200, {
    "Content-Type": mimeTypes[extname(filePath)] || "application/octet-stream",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  createReadStream(filePath).pipe(response);
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`ALMSTH WIKI FAILED: http://${host}:${port} is already in use.`);
  } else {
    console.error(`ALMSTH WIKI FAILED: ${error.message}`);
  }
  process.exitCode = 1;
});

server.listen(port, host, () => {
  console.log(`ALMSTH WIKI READY: http://${host}:${port}`);
  console.log("Press Ctrl+C to stop.");
});
