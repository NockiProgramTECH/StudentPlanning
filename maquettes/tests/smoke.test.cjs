const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.join(__dirname, "..");

function app() {
  const dom = new JSDOM(
    fs.readFileSync(path.join(root, "index.html"), "utf8"),
    {
      runScripts: "outside-only",
      url: "http://localhost:4173/",
    },
  );
  dom.window.eval(fs.readFileSync(path.join(root, "app.js"), "utf8"));
  return { window: dom.window, doc: dom.window.document };
}

function click(doc, selector) {
  const button = doc.querySelector(selector);
  assert.ok(button, `Missing ${selector}`);
  button.click();
}

test("les six écrans et la correction du cours sont accessibles sans API", () => {
  const { window, doc } = app();
  assert.match(doc.querySelector("#app").textContent, /Votre semaine/);
  assert.equal(doc.querySelectorAll("#screen-nav button").length, 6);
  click(doc, '[data-screen="import"]');
  assert.match(doc.querySelector("#app").textContent, /Un PDF/);
  click(doc, '[data-action="simulate"]');
  assert.match(doc.querySelector("#app").textContent, /À vous de/);
  click(doc, '[data-edit="2"]');
  doc.querySelector('#edit-form [name="room"]').value = "A104";
  doc
    .querySelector("#edit-form")
    .dispatchEvent(
      new window.Event("submit", { bubbles: true, cancelable: true }),
    );
  assert.match(doc.querySelector("#app").textContent, /A104/);
  click(doc, '[data-screen="compare"]');
  assert.match(doc.querySelector("#app").textContent, /Ce qui/);
  click(doc, '[data-screen="history"]');
  assert.match(doc.querySelector("#app").textContent, /Vos semaines/);
  click(doc, '[data-week="2026-10-05"]');
  assert.match(doc.querySelector("#app").textContent, /Ma semaine/);
  click(doc, '[data-day="3"]');
  assert.match(doc.querySelector("#app").textContent, /Mercredi/);
});

test("les saisies utilisateur sont échappées dans le HTML", () => {
  const { doc } = app();
  click(doc, '[data-screen="import"]');
  const input = doc.querySelector("#class-name");
  input.value = "<img src=x onerror=alert(1)>";
  input.dispatchEvent(new doc.defaultView.Event("input", { bubbles: true }));
  click(doc, '[data-screen="home"]');
  assert.equal(doc.querySelector(".hero-card img"), null);
  assert.match(doc.querySelector(".hero-card").textContent, /<img src=x/);
});

test("les exemples rouge et jaune sont visibles et modifiables", () => {
  const { doc } = app();
  click(doc, '[data-screen="planning"]');
  click(doc, '[data-day="2"]');
  assert.match(doc.querySelector("#app").textContent, /EN LIGNE/);
  click(doc, '[data-day="3"]');
  assert.match(doc.querySelector("#app").textContent, /DEVOIR/);
  click(doc, '[data-screen="review"]');
  click(doc, '[data-edit="5"]');
  assert.equal(doc.querySelector('[name="kind"]').value, "assessment");
});
