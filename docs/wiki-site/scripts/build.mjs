import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, copyFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const siteRoot = resolve(scriptDir, "..");
const wikiRoot = resolve(siteRoot, "../wiki");
const distRoot = resolve(siteRoot, "dist");
const checkOnly = process.argv.includes("--check");

const pageOrder = [
  ["README.md", "Начало"],
  ["current-snapshot.md", "Начало"],
  ["roadmap.md", "Начало"],
  ["prompt-template.md", "Начало"],
  ["progression.md", "Системы"],
  ["skills-and-abilities.md", "Системы"],
  ["economy.md", "Системы"],
  ["items.md", "Системы"],
  ["enemies.md", "Системы"],
  ["special-mechanics.md", "Системы"],
  ["generated/game-reference.md", "Справочник"],
];
const statuses = ["implemented", "partial", "placeholder", "planned", "absent"];

function slugFor(file) {
  return file.replace(/^generated\//, "generated-").replace(/\.md$/, "");
}

function titleFrom(markdown, file) {
  const match = markdown.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : file;
}

function headingId(text) {
  return text.toLowerCase().replace(/`/g, "").replace(/[^a-zа-яё0-9\s-]/gi, "").trim().replace(/\s+/g, "-");
}

function headingIdsFrom(markdown) {
  return new Set([...markdown.matchAll(/^#{1,6}\s+(.+)$/gm)].map((match) => headingId(match[1].trim())));
}

function summaryFrom(markdown) {
  const lines = markdown.split(/\r?\n/);
  const paragraphs = [];
  let current = [];
  for (const line of lines.slice(1)) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (current.length) break;
      continue;
    }
    if (/^(#|\||-|>|```|Статус)/.test(trimmed)) continue;
    current.push(trimmed);
  }
  return current.join(" ").replace(/[`*_]/g, "").slice(0, 220);
}

function buildManifest() {
  const pages = pageOrder.map(([file, section]) => {
    const sourcePath = join(wikiRoot, ...file.split("/"));
    if (!existsSync(sourcePath)) throw new Error(`Wiki source is missing: ${file}`);
    const content = readFileSync(sourcePath, "utf8").replace(/\r\n/g, "\n");
    for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
      const href = match[1];
      if (/^(https?:|mailto:)/.test(href)) continue;
      const [pathPart, anchorPart = ""] = href.split("#");
      const relativePath = decodeURIComponent(pathPart);
      const target = relativePath ? resolve(dirname(sourcePath), relativePath) : sourcePath;
      if (!target.startsWith(wikiRoot) || !existsSync(target)) {
        throw new Error(`Broken wiki link in ${file}: ${href}`);
      }
      if (anchorPart) {
        const targetContent = readFileSync(target, "utf8").replace(/\r\n/g, "\n");
        const anchor = headingId(decodeURIComponent(anchorPart));
        if (!headingIdsFrom(targetContent).has(anchor)) {
          throw new Error(`Broken wiki anchor in ${file}: ${href}`);
        }
      }
    }
    const statusMatch = content.match(/^Статус(?:ы)?:\s*(.+)$/m);
    const firstSection = content.indexOf("\n## ");
    if (!statusMatch || (firstSection >= 0 && statusMatch.index > firstSection)) {
      throw new Error(`Wiki page has no top-level status line: ${file}`);
    }
    const statusLine = statusMatch[1];
    const declaredStatuses = [...statusLine.matchAll(/`([^`]+)`/g)].map((match) => match[1]);
    const unknownStatuses = declaredStatuses.filter((status) => !statuses.includes(status));
    if (!declaredStatuses.length || unknownStatuses.length) {
      throw new Error(`Wiki page has an invalid status line in ${file}: ${statusLine}`);
    }
    const foundStatuses = statuses.filter((status) => new RegExp(`\\b${status}\\b`, "i").test(statusLine));
    return {
      slug: slugFor(file),
      file,
      section,
      title: titleFrom(content, file),
      summary: summaryFrom(content),
      statuses: foundStatuses,
      content,
    };
  });
  return JSON.stringify({ schemaVersion: 1, pages }, null, 2) + "\n";
}

const manifest = buildManifest();
const manifestPath = join(distRoot, "content", "manifest.json");

if (checkOnly) {
  if (!existsSync(manifestPath) || readFileSync(manifestPath, "utf8") !== manifest) {
    console.error("Wiki site build is stale. Run the site build.");
    process.exit(1);
  }
  for (const file of ["index.html", "app.js", "styles.css"]) {
    const source = join(siteRoot, "src", file);
    const built = join(distRoot, file);
    if (!existsSync(built) || readFileSync(source, "utf8") !== readFileSync(built, "utf8")) {
      console.error(`Wiki site asset is stale: ${file}`);
      process.exit(1);
    }
  }
  const referenceSource = join(wikiRoot, "generated", "game-reference.json");
  const referenceBuilt = join(distRoot, "content", "game-reference.json");
  if (!existsSync(referenceBuilt) || readFileSync(referenceSource, "utf8") !== readFileSync(referenceBuilt, "utf8")) {
    console.error("Wiki site generated reference is stale: content/game-reference.json");
    process.exit(1);
  }
  console.log("ALMSTH WIKI SITE IS FRESH");
  process.exit(0);
}

rmSync(distRoot, { recursive: true, force: true });
mkdirSync(join(distRoot, "content"), { recursive: true });
for (const file of ["index.html", "app.js", "styles.css"]) {
  copyFileSync(join(siteRoot, "src", file), join(distRoot, file));
}
writeFileSync(manifestPath, manifest);
copyFileSync(
  join(wikiRoot, "generated", "game-reference.json"),
  join(distRoot, "content", "game-reference.json"),
);
console.log(`ALMSTH WIKI SITE BUILT: ${distRoot}`);
