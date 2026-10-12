const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.resolve(__dirname, "..");
function site() {
  const dom = new JSDOM(
    fs.readFileSync(path.join(root, "index.html"), "utf8"),
    {
      url: "https://studia.example/",
      runScripts: "outside-only",
    },
  );
  // jsdom has no native dialog renderer. The browser checks cover native modal behavior.
  dom.window.HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute("open", "");
  };
  dom.window.HTMLDialogElement.prototype.close = function () {
    this.removeAttribute("open");
    this.dispatchEvent(new dom.window.Event("close"));
  };
  dom.window.eval(fs.readFileSync(path.join(root, "app.js"), "utf8"));
  return dom;
}
function click(doc, selector) {
  const el = doc.querySelector(selector);
  assert.ok(el, `Missing selector: ${selector}`);
  el.click();
  return el;
}

test("French site has valid anchors, local assets and an honest development status", () => {
  const dom = site();
  const doc = dom.window.document;
  assert.equal(doc.documentElement.lang, "fr");
  assert.equal(doc.querySelectorAll("h1").length, 1);
  for (const link of doc.querySelectorAll('a[href^="#"]')) {
    if (link.hash) assert.ok(doc.getElementById(link.hash.slice(1)), link.hash);
  }
  for (const el of doc.querySelectorAll("[src],link[href]")) {
    const asset = el.getAttribute("src") || el.getAttribute("href");
    if (!asset.startsWith("http"))
      assert.ok(fs.existsSync(path.join(root, asset)), asset);
  }
  assert.match(
    doc.body.textContent.replace(/\s+/g, " "),
    /pas encore de téléchargement public/,
  );
  assert.match(doc.body.textContent, /Données fictives/);
  assert.equal(doc.querySelectorAll("form,iframe").length, 0);
  dom.window.close();
});

test("mobile navigation opens and closes on selection or Escape", () => {
  const dom = site();
  const doc = dom.window.document;
  click(doc, ".menu-toggle");
  assert.equal(
    doc.querySelector(".menu-toggle").getAttribute("aria-expanded"),
    "true",
  );
  click(doc, "#main-nav a");
  assert.equal(
    doc.querySelector(".menu-toggle").getAttribute("aria-expanded"),
    "false",
  );
  click(doc, ".menu-toggle");
  doc.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Escape", bubbles: true }),
  );
  assert.equal(
    doc.querySelector(".menu-toggle").getAttribute("aria-expanded"),
    "false",
  );
  assert.equal(doc.activeElement, doc.querySelector(".menu-toggle"));
  dom.window.close();
});

test("hero days switch the fictitious course and selected day", () => {
  const dom = site();
  const doc = dom.window.document;
  click(doc, '[data-hero-day="2"]');
  assert.match(
    doc.querySelector("#hero-course").textContent,
    /Transmission des signaux/,
  );
  assert.match(doc.querySelector(".phone-greeting").textContent, /MERCREDI 14/);
  assert.equal(
    doc.querySelectorAll('[data-hero-day][aria-pressed="true"]').length,
    1,
  );
  dom.window.close();
});

test("method tabs support clicks and keyboard with consistent ARIA state", () => {
  const dom = site();
  const doc = dom.window.document;
  const second = click(doc, '[data-step="1"]');
  assert.match(doc.querySelector("#step-panel").textContent, /dernier mot/);
  second.focus();
  second.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", {
      key: "ArrowDown",
      bubbles: true,
    }),
  );
  assert.equal(
    doc.querySelector("#step-panel").getAttribute("aria-labelledby"),
    "step-2",
  );
  assert.match(
    doc.querySelector("#step-panel").textContent,
    /Tout est à sa place/,
  );
  assert.equal(
    doc.querySelectorAll('[data-step][aria-selected="true"]').length,
    1,
  );
  dom.window.close();
});

test("demo planning, revisions and quiz work without network or storage", () => {
  const dom = site();
  const doc = dom.window.document;
  let networkCalls = 0;
  dom.window.fetch = () => {
    networkCalls++;
    throw new Error("Unexpected network call");
  };
  const trigger = click(doc, "[data-open-demo]");
  assert.ok(doc.querySelector("#demo-dialog").open);
  click(doc, '[data-demo-day="4"]');
  assert.match(
    doc.querySelector("#demo-panel").textContent,
    /Électronique analogique/,
  );
  click(doc, '[data-demo-tab="revisions"]');
  click(doc, '[data-revision="0"]');
  assert.match(doc.querySelector("#revision-count").textContent, /1 \/ 3/);
  assert.equal(doc.querySelector("progress").value, 1);
  click(doc, '[data-demo-tab="quiz"]');
  click(doc, '[data-answer="0"]');
  assert.match(
    doc.querySelector("#quiz-result").textContent,
    /Pas tout à fait/,
  );
  assert.ok(
    doc.querySelector('[data-answer="1"]').classList.contains("correct"),
  );
  assert.equal(doc.querySelectorAll("[data-answer]:disabled").length, 3);
  click(doc, "[data-reset-quiz]");
  click(doc, '[data-answer="1"]');
  assert.match(doc.querySelector("#quiz-result").textContent, /Exactement/);
  click(doc, '[data-demo-tab="revisions"]');
  assert.ok(doc.querySelector('[data-revision="0"]').checked);
  click(doc, "#demo-dialog .close-dialog");
  assert.ok(!doc.body.classList.contains("modal-open"));
  assert.equal(doc.activeElement, trigger);
  click(doc, "[data-open-demo]");
  click(doc, '[data-demo-tab="revisions"]');
  assert.equal(doc.querySelector("progress").value, 0);
  click(doc, '[data-demo-tab="quiz"]');
  assert.equal(doc.querySelectorAll("[data-answer]:disabled").length, 0);
  assert.equal(networkCalls, 0);
  assert.equal(dom.window.localStorage.length, 0);
  dom.window.close();
});

test("privacy modal and external links are explicit", () => {
  const dom = site();
  const doc = dom.window.document;
  click(doc, "[data-open-privacy]");
  assert.ok(doc.querySelector("#privacy-dialog").open);
  assert.match(
    doc.querySelector("#privacy-dialog").textContent,
    /journaux techniques/,
  );
  click(doc, "#privacy-dialog .close-dialog");
  assert.ok(!doc.querySelector("#privacy-dialog").open);
  for (const link of doc.querySelectorAll('a[target="_blank"]')) {
    assert.ok(link.rel.includes("noopener"));
    assert.ok(link.rel.includes("noreferrer"));
  }
  const css = fs.readFileSync(path.join(root, "styles.css"), "utf8");
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /focus-visible/);
  dom.window.close();
});
