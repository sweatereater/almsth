const STATUS_LABELS = {
  all: "Все",
  implemented: "Работает",
  partial: "Частично",
  placeholder: "Пусто",
  planned: "В плане",
  absent: "Нет",
};

const state = {
  pages: [],
  pageBySlug: new Map(),
  activeSlug: "current-snapshot",
  status: "all",
  query: "",
};

const elements = {
  article: document.querySelector("#wiki-article"),
  breadcrumb: document.querySelector("#breadcrumb"),
  filters: document.querySelector("#status-filters"),
  loading: document.querySelector("#loading"),
  menuButton: document.querySelector("#menu-button"),
  nav: document.querySelector("#wiki-nav"),
  results: document.querySelector("#search-results"),
  scrim: document.querySelector("#scrim"),
  search: document.querySelector("#wiki-search"),
  sidebar: document.querySelector("#sidebar"),
  toast: document.querySelector("#toast"),
};

init();

async function init() {
  try {
    const response = await fetch("/content/manifest.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const manifest = await response.json();
    state.pages = manifest.pages;
    state.pageBySlug = new Map(state.pages.map((page) => [page.slug, page]));
    buildFilters();
    bindEvents();
    routeFromHash(false);
    render();
    elements.loading.hidden = true;
  } catch (error) {
    elements.loading.textContent = `Не удалось прочитать локальные страницы: ${error.message}`;
    elements.loading.classList.add("error");
  }
}

function buildFilters() {
  for (const id of Object.keys(STATUS_LABELS)) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `status-chip status-${id}`;
    button.dataset.status = id;
    button.textContent = STATUS_LABELS[id];
    button.setAttribute("aria-pressed", String(id === state.status));
    elements.filters.append(button);
  }
}

function bindEvents() {
  elements.search.addEventListener("input", () => {
    state.query = elements.search.value.trim();
    render();
  });
  elements.filters.addEventListener("click", (event) => {
    const button = event.target.closest("[data-status]");
    if (!button) return;
    state.status = button.dataset.status;
    for (const chip of elements.filters.querySelectorAll("[data-status]")) {
      chip.setAttribute("aria-pressed", String(chip === button));
    }
    render();
  });
  elements.nav.addEventListener("click", (event) => {
    const link = event.target.closest("[data-page]");
    if (!link) return;
    event.preventDefault();
    openPage(link.dataset.page);
  });
  elements.results.addEventListener("click", (event) => {
    const link = event.target.closest("[data-page]");
    if (!link) return;
    openPage(link.dataset.page);
  });
  elements.article.addEventListener("click", (event) => {
    const link = event.target.closest("[data-page]");
    if (!link) return;
    event.preventDefault();
    openPage(link.dataset.page, link.dataset.anchor || "");
  });
  document.addEventListener("click", (event) => {
    const copyButton = event.target.closest("[data-copy-page]");
    if (copyButton) copyPage(copyButton.dataset.copyPage);
  });
  elements.menuButton.addEventListener("click", () => toggleMenu());
  elements.scrim.addEventListener("click", () => toggleMenu(false));
  window.addEventListener("hashchange", () => {
    routeFromHash(false);
    render();
  });
  document.addEventListener("keydown", (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      elements.search.focus();
      elements.search.select();
    } else if (event.key === "/" && !isTyping(event.target)) {
      event.preventDefault();
      elements.search.focus();
    } else if (event.key === "Escape") {
      if (state.query) {
        elements.search.value = "";
        state.query = "";
        render();
        elements.search.focus();
      } else {
        toggleMenu(false);
      }
    }
  });
}

function render() {
  renderNav();
  if (state.query) renderSearchResults();
  else renderPage();
}

function renderNav() {
  const visible = filteredPages();
  const sections = [...new Set(state.pages.map((page) => page.section))];
  elements.nav.innerHTML = sections.map((section) => {
    const pages = visible.filter((page) => page.section === section);
    if (!pages.length) return "";
    return `<section class="nav-section"><div class="section-caption">${escapeHtml(section)}</div>${pages.map((page) => `
      <a href="#${page.slug}" data-page="${page.slug}" class="nav-link ${page.slug === state.activeSlug ? "active" : ""}" ${page.slug === state.activeSlug ? 'aria-current="page"' : ""}>
        <span>${escapeHtml(page.title)}</span>${statusMarks(page.statuses)}
      </a>`).join("")}</section>`;
  }).join("");
}

function renderPage() {
  const page = state.pageBySlug.get(state.activeSlug) || state.pages[0];
  if (!page) return;
  state.activeSlug = page.slug;
  elements.results.hidden = true;
  elements.article.hidden = false;
  elements.article.innerHTML = `<div class="page-meta">${page.statuses.map(statusBadge).join("")}</div>${renderMarkdown(page.content, page.slug)}`;
  elements.breadcrumb.textContent = `${page.section} / ${page.title}`;
  document.title = `${page.title} · Almsth Wiki`;
}

function renderSearchResults() {
  const needle = normalizeText(state.query);
  const matches = filteredPages()
    .map((page) => ({ page, score: searchScore(page, needle), snippet: searchSnippet(page, needle) }))
    .filter((entry) => entry.score > 0)
    .sort((a, b) => b.score - a.score || a.page.title.localeCompare(b.page.title, "ru"));
  elements.article.hidden = true;
  elements.results.hidden = false;
  elements.breadcrumb.textContent = `Поиск / ${state.query}`;
  elements.results.innerHTML = `
    <header class="results-header"><p class="eyebrow">Полнотекстовый поиск</p><h1>«${escapeHtml(state.query)}»</h1><p>${matches.length ? `Найдено страниц: ${matches.length}` : "Совпадений нет"}</p></header>
    <div class="result-list">${matches.map(({ page, snippet }) => `
      <button type="button" class="result-card" data-page="${page.slug}">
        <span class="result-section">${escapeHtml(page.section)}</span>
        <strong>${escapeHtml(page.title)}</strong>
        <span>${highlight(snippet, state.query)}</span>
        <span class="result-statuses">${page.statuses.map(statusBadge).join("")}</span>
      </button>`).join("")}</div>`;
}

function filteredPages() {
  if (state.status === "all") return state.pages;
  return state.pages.filter((page) => page.statuses.includes(state.status));
}

function openPage(slug, anchor = "") {
  if (!state.pageBySlug.has(slug)) return;
  state.activeSlug = slug;
  state.query = "";
  elements.search.value = "";
  const nextHash = `#${slug}${anchor ? `/${anchor}` : ""}`;
  if (location.hash === nextHash) {
    render();
    scrollToAnchor(anchor);
  } else {
    location.hash = nextHash;
    setTimeout(() => scrollToAnchor(anchor), 0);
  }
  toggleMenu(false);
}

function routeFromHash() {
  const raw = decodeURIComponent(location.hash.replace(/^#/, ""));
  const [slug] = raw.split("/");
  if (state.pageBySlug.has(slug)) state.activeSlug = slug;
}

function scrollToAnchor(anchor) {
  if (!anchor) {
    window.scrollTo({ top: 0, behavior: "smooth" });
    return;
  }
  requestAnimationFrame(() => document.getElementById(anchor)?.scrollIntoView({ behavior: "smooth", block: "start" }));
}

async function copyPage(slug) {
  const page = state.pageBySlug.get(slug);
  if (!page) return;
  try {
    await navigator.clipboard.writeText(page.content);
  } catch {
    const area = document.createElement("textarea");
    area.value = page.content;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.append(area);
    area.select();
    document.execCommand("copy");
    area.remove();
  }
  showToast(slug === "current-snapshot" ? "Текущий срез скопирован" : "Шаблон промта скопирован");
}

function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("visible");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => elements.toast.classList.remove("visible"), 2200);
}

function toggleMenu(force) {
  const open = typeof force === "boolean" ? force : !document.body.classList.contains("menu-open");
  document.body.classList.toggle("menu-open", open);
  elements.menuButton.setAttribute("aria-expanded", String(open));
  if (open) elements.search.focus();
}

function renderMarkdown(markdown, currentSlug) {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const output = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) { index += 1; continue; }
    if (line.startsWith("```")) {
      const language = line.slice(3).trim();
      const code = [];
      index += 1;
      while (index < lines.length && !lines[index].startsWith("```")) code.push(lines[index++]);
      index += 1;
      output.push(`<pre><code${language ? ` data-language="${escapeHtml(language)}"` : ""}>${escapeHtml(code.join("\n"))}</code></pre>`);
      continue;
    }
    const heading = line.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      const level = heading[1].length;
      const text = heading[2].trim();
      const id = headingId(text);
      output.push(`<h${level} id="${id}">${inlineMarkdown(text, currentSlug)}</h${level}>`);
      index += 1;
      continue;
    }
    if (line.trim().startsWith("|") && index + 1 < lines.length && /^\s*\|?(\s*:?-+:?\s*\|)+\s*$/.test(lines[index + 1])) {
      const rows = [splitTableRow(line)];
      index += 2;
      while (index < lines.length && lines[index].trim().startsWith("|")) rows.push(splitTableRow(lines[index++]));
      const head = rows.shift();
      output.push(`<div class="table-wrap"><table><thead><tr>${head.map((cell) => `<th>${inlineMarkdown(cell, currentSlug)}</th>`).join("")}</tr></thead><tbody>${rows.map((row) => `<tr>${row.map((cell) => `<td>${inlineMarkdown(cell, currentSlug)}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`);
      continue;
    }
    if (/^\s*[-*]\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^\s*[-*]\s+/.test(lines[index])) items.push(lines[index++].replace(/^\s*[-*]\s+/, ""));
      output.push(`<ul>${items.map((item) => `<li>${inlineMarkdown(item, currentSlug)}</li>`).join("")}</ul>`);
      continue;
    }
    if (/^\s*\d+\.\s+/.test(line)) {
      const items = [];
      while (index < lines.length && /^\s*\d+\.\s+/.test(lines[index])) items.push(lines[index++].replace(/^\s*\d+\.\s+/, ""));
      output.push(`<ol>${items.map((item) => `<li>${inlineMarkdown(item, currentSlug)}</li>`).join("")}</ol>`);
      continue;
    }
    if (line.trim().startsWith(">")) {
      const quote = [];
      while (index < lines.length && lines[index].trim().startsWith(">")) quote.push(lines[index++].replace(/^\s*>\s?/, ""));
      output.push(`<blockquote>${quote.map((part) => inlineMarkdown(part, currentSlug)).join("<br>")}</blockquote>`);
      continue;
    }
    const paragraph = [line.trim()];
    index += 1;
    while (index < lines.length && lines[index].trim() && !/^(#{1,6})\s|^```|^\s*[-*]\s+|^\s*\d+\.\s+|^\s*>|^\s*\|/.test(lines[index])) {
      paragraph.push(lines[index++].trim());
    }
    output.push(`<p>${inlineMarkdown(paragraph.join(" "), currentSlug)}</p>`);
  }
  return output.join("\n");
}

function inlineMarkdown(value, currentSlug) {
  const tokens = [];
  let html = escapeHtml(value).replace(/`([^`]+)`/g, (_, code) => {
    const token = `@@CODE${tokens.length}@@`;
    tokens.push(`<code>${code}</code>`);
    return token;
  });
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
    if (/^(https?:|mailto:)/.test(href)) return `<a href="${href}" rel="noreferrer">${label}</a>`;
    const [path, fragment = ""] = href.split("#");
    const slug = path ? path.replace(/^generated\//, "generated-").replace(/\.md$/, "") : currentSlug;
    return `<a href="#${slug}" data-page="${slug}" data-anchor="${fragment}">${label}</a>`;
  });
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>").replace(/\*([^*]+)\*/g, "<em>$1</em>");
  tokens.forEach((token, index) => { html = html.replace(`@@CODE${index}@@`, token); });
  return html;
}

function splitTableRow(line) {
  return line.trim().replace(/^\|/, "").replace(/\|$/, "").split(/(?<!\\)\|/).map((cell) => cell.trim().replace(/\\\|/g, "|"));
}

function headingId(text) {
  return text.toLowerCase().replace(/`/g, "").replace(/[^a-zа-яё0-9\s-]/gi, "").trim().replace(/\s+/g, "-");
}

function statusMarks(statuses) {
  return `<span class="nav-marks">${statuses.slice(0, 3).map((status) => `<i class="mark status-${status}" title="${STATUS_LABELS[status]}"></i>`).join("")}</span>`;
}

function statusBadge(status) {
  return `<span class="status-badge status-${status}">${status}</span>`;
}

function searchScore(page, needle) {
  const title = normalizeText(page.title);
  const content = normalizeText(page.content);
  let score = 0;
  if (title.includes(needle)) score += 12;
  if (normalizeText(page.summary).includes(needle)) score += 6;
  let cursor = 0;
  while ((cursor = content.indexOf(needle, cursor)) >= 0) { score += 1; cursor += needle.length; }
  return score;
}

function searchSnippet(page, needle) {
  const plain = page.content.replace(/```[\s\S]*?```/g, " ").replace(/[#|`>*_[\]()]/g, " ").replace(/\s+/g, " ").trim();
  const index = normalizeText(plain).indexOf(needle);
  if (index < 0) return page.summary || plain.slice(0, 180);
  return `${index > 70 ? "…" : ""}${plain.slice(Math.max(0, index - 70), index + needle.length + 120)}…`;
}

function highlight(text, query) {
  const escaped = escapeHtml(text);
  const pattern = new RegExp(`(${escapeRegExp(query)})`, "ig");
  return escaped.replace(pattern, "<mark>$1</mark>");
}

function normalizeText(value) {
  return String(value).toLocaleLowerCase("ru-RU").replace(/ё/g, "е");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" })[character]);
}

function isTyping(target) {
  return target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target?.isContentEditable;
}
