const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const root = path.resolve(__dirname, "..");
function site(fetchImpl) {
  const dom = new JSDOM(
    fs.readFileSync(path.join(root, "index.html"), "utf8"),
    {
      url: "https://studia.example/",
      runScripts: "outside-only",
    },
  );
  if (fetchImpl) dom.window.fetch = fetchImpl;
  // jsdom has no native dialog renderer. The browser checks cover native modal behavior.
  dom.window.HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute("open", "");
  };
  dom.window.HTMLDialogElement.prototype.close = function () {
    this.removeAttribute("open");
    this.dispatchEvent(new dom.window.Event("close"));
  };
  dom.window.eval(fs.readFileSync(path.join(root, "app.js"), "utf8"));
  dom.window.eval(fs.readFileSync(path.join(root, "beta.js"), "utf8"));
  dom.window.eval(fs.readFileSync(path.join(root, "feedback.js"), "utf8"));
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
    /versions bêta Android sont proposées/,
  );
  assert.match(doc.body.textContent, /Données fictives/);
  assert.equal(doc.querySelectorAll("iframe").length, 0);
  assert.equal(doc.querySelectorAll("form").length, 1);
  assert.equal(doc.querySelector("form").id, "feedback-form");
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

test("positioning welcomes students beyond the initial pilot class", () => {
  const dom = site();
  const doc = dom.window.document;
  const text = doc.body.textContent.replace(/\s+/g, " ");
  assert.doesNotMatch(text, /\bL2\s+SIR\b/);
  assert.doesNotMatch(
    doc.querySelector('meta[name="description"]').content,
    /L2 SIR/,
  );
  assert.match(text, /quelle que soit leur classe ou leur filière/);
  assert.match(text, /compatibilité avec les différents formats/);
  assert.equal(doc.querySelector(".nav-cta").hash, "#beta");
  assert.equal(doc.querySelector(".hero-actions a").hash, "#beta");
  dom.window.close();
});

const officialApk =
  "https://github.com/NockiProgramTECH/StudentPlanning/releases/download/v0.1.0-beta.1/studia-beta.apk";
function release(overrides = {}) {
  return {
    tag_name: "v0.1.0-beta.1",
    prerelease: true,
    draft: false,
    published_at: "2026-10-12T12:00:00Z",
    assets: [
      {
        name: "studia-beta.apk",
        state: "uploaded",
        size: 10485760,
        browser_download_url: officialApk,
      },
    ],
    ...overrides,
  };
}
const settle = () => new Promise((resolve) => setImmediate(resolve));

test("no request on load; download only appears for an actual official beta asset", async () => {
  const calls = [];
  const dom = site(async (url, options) => {
    calls.push({ url, options });
    return { ok: true, json: async () => [release()] };
  });
  const doc = dom.window.document;
  assert.equal(calls.length, 0);
  assert.equal(doc.querySelector("#beta-download").hidden, true);
  assert.equal(doc.querySelector("#beta-download").hasAttribute("href"), false);
  click(doc, "#beta-check");
  assert.ok(doc.querySelector("#beta-check").disabled);
  await settle();
  assert.equal(calls.length, 1);
  assert.match(
    calls[0].url,
    /^https:\/\/api.github.com\/repos\/NockiProgramTECH\/StudentPlanning\/releases\?/,
  );
  assert.equal(calls[0].options.credentials, "omit");
  assert.equal(calls[0].options.referrerPolicy, "no-referrer");
  assert.equal(doc.querySelector("#beta-download").href, officialApk);
  assert.equal(doc.querySelector("#beta-download").hidden, false);
  assert.match(
    doc.querySelector("#beta-file-details").textContent,
    /v0.1.0-beta.1.*10 Mo/,
  );
  assert.equal(doc.querySelector("#beta-check").disabled, false);
  assert.equal(dom.window.localStorage.length, 0);
  dom.window.close();
});

test("missing, ambiguous and unsafe APKs never produce a download link", async () => {
  const badAssets = [
    [],
    [release({ draft: true })],
    [release({ prerelease: false, tag_name: "v1.0.0" })],
    [release({ published_at: "not-a-date" })],
    [release({ assets: [{ ...release().assets[0], size: 0 }] })],
    [release({ assets: [{ ...release().assets[0], name: "archive.zip" }] })],
    [release({ assets: [{ ...release().assets[0], state: "new" }] })],
    ...[
      "javascript:alert(1)",
      "https://github.com.evil.example/a.apk",
      "https://github.com/another/repo/releases/download/beta/app.apk",
      "https://github.com/NockiProgramTECH/StudentPlanning/releases/tag/beta",
      "http://github.com/NockiProgramTECH/StudentPlanning/releases/download/beta/app.apk",
    ].map((url) => [
      release({
        assets: [{ ...release().assets[0], browser_download_url: url }],
      }),
    ]),
    [
      release({
        assets: [
          { ...release().assets[0], name: "arm64.apk" },
          { ...release().assets[0], name: "x86.apk" },
        ],
      }),
    ],
  ];
  for (const payload of badAssets) {
    const dom = site(async () => ({ ok: true, json: async () => payload }));
    const doc = dom.window.document;
    click(doc, "#beta-check");
    await settle();
    assert.equal(doc.querySelector("#beta-download").hidden, true);
    assert.equal(
      doc.querySelector("#beta-download").hasAttribute("href"),
      false,
    );
    assert.match(doc.querySelector("#beta-status").textContent, /Aucun APK/);
    dom.window.close();
  }
});

test("most recently published valid beta wins; failed recheck removes the stale download", async () => {
  let fail = false;
  const latest = officialApk.replace("v0.1.0-beta.1", "v0.2.0-beta.1");
  const dom = site(async () => {
    if (fail) throw new Error("network unavailable");
    return {
      ok: true,
      json: async () => [
        release(),
        release({
          published_at: "2026-10-13T12:00:00Z",
          tag_name: "v0.2.0-beta.1",
          assets: [{ ...release().assets[0], browser_download_url: latest }],
        }),
      ],
    };
  });
  const doc = dom.window.document;
  click(doc, "#beta-check");
  await settle();
  assert.equal(doc.querySelector("#beta-download").href, latest);
  fail = true;
  click(doc, "#beta-check");
  await settle();
  assert.equal(doc.querySelector("#beta-download").hasAttribute("href"), false);
  assert.equal(doc.querySelector("#beta-download").hidden, true);
  assert.match(
    doc.querySelector("#beta-status").textContent,
    /Impossible de vérifier/,
  );
  assert.equal(doc.querySelector("#beta-check").disabled, false);
  dom.window.close();
});

test("GitHub throttling and malformed responses permit retry without fake availability", async () => {
  for (const response of [
    { ok: false, status: 403 },
    { ok: true, json: async () => ({ message: "invalid" }) },
  ]) {
    const dom = site(async () => response);
    click(dom.window.document, "#beta-check");
    await settle();
    assert.equal(
      dom.window.document.querySelector("#beta-download").hidden,
      true,
    );
    assert.equal(
      dom.window.document.querySelector("#beta-check").disabled,
      false,
    );
    assert.match(
      dom.window.document.querySelector("#beta-status").textContent,
      /Impossible/,
    );
    dom.window.close();
  }
});

test("feedback is a real prefilled issue with public-data warning, not a fake form", () => {
  const dom = site();
  const url = new URL(
    dom.window.document.querySelector("#beta-feedback-link").href,
  );
  assert.equal(url.origin, "https://github.com");
  assert.equal(url.pathname, "/NockiProgramTECH/StudentPlanning/issues/new");
  assert.match(url.searchParams.get("body"), /ce retour est public/);
  assert.match(url.searchParams.get("body"), /Version Studia/);
  assert.match(url.searchParams.get("body"), /Ce qui m’aide/);
  assert.match(url.searchParams.get("body"), /aucun code d’accès/);
  dom.window.close();
});

test("feedback and suggestion section toggles modes, updates inputs, and handles quick suggestions", async () => {
  const dom = site();
  const doc = dom.window.document;

  const section = doc.querySelector("#retours");
  assert.ok(section, "Missing #retours section");

  // Par défaut, mode suggestion sélectionné
  const tabSug = doc.querySelector("#tab-suggestion");
  const tabRet = doc.querySelector("#tab-retour");
  assert.equal(tabSug.getAttribute("aria-selected"), "true");
  assert.equal(tabRet.getAttribute("aria-selected"), "false");
  assert.match(
    doc.querySelector("#feedback-subject-label").textContent,
    /suggestion/i,
  );

  // Vérifier la présence des suggestions rapides initiales
  const quickChips = doc.querySelectorAll(".quick-idea-chip");
  assert.ok(quickChips.length >= 4);

  // Cliquer sur une suggestion rapide doit pré-remplir le titre et la description
  click(doc, ".quick-idea-chip");
  const titleInput = doc.querySelector("#feedback-title-input");
  const descInput = doc.querySelector("#feedback-desc-input");
  assert.ok(titleInput.value.length > 0);
  assert.ok(descInput.value.length > 0);

  // Basculer en mode retour
  click(doc, "#tab-retour");
  assert.equal(tabSug.getAttribute("aria-selected"), "false");
  assert.equal(tabRet.getAttribute("aria-selected"), "true");
  assert.match(
    doc.querySelector("#feedback-subject-label").textContent,
    /retour/i,
  );

  // Vérifier le changement de catégorie
  click(doc, '[data-category="quiz"]');
  assert.equal(doc.querySelector("#feedback-category").value, "quiz");
  assert.equal(
    doc.querySelector('[data-category="quiz"]').getAttribute("aria-pressed"),
    "true",
  );

  // Tester l'action GitHub
  titleInput.value = "Bug affichage calendrier";
  titleInput.dispatchEvent(new dom.window.Event("input"));
  descInput.value = "Les cours se chevauchent le vendredi après-midi.";
  descInput.dispatchEvent(new dom.window.Event("input"));

  const btnGithub = doc.querySelector("#btn-github-issue");
  assert.ok(btnGithub.href, "GitHub issue URL should be set");
  const parsedGithub = new URL(btnGithub.href);
  assert.equal(parsedGithub.origin, "https://github.com");
  assert.equal(
    parsedGithub.pathname,
    "/NockiProgramTECH/StudentPlanning/issues/new",
  );
  assert.match(parsedGithub.searchParams.get("title"), /\[Retour\]/);
  assert.match(parsedGithub.searchParams.get("title"), /Bug affichage/);
  assert.match(parsedGithub.searchParams.get("body"), /chevauchent/);
  assert.match(parsedGithub.searchParams.get("labels"), /feedback/);

  // Tester l'action e-mail
  const btnEmail = doc.querySelector("#btn-email-feedback");
  assert.match(btnEmail.href, /^mailto:/);
  assert.match(btnEmail.href, /contact@studia-app.fr/);
  assert.match(btnEmail.href, /Bug%20affichage/);

  // Tester le basculement retour vers suggestion
  click(doc, "#tab-suggestion");
  assert.equal(tabSug.getAttribute("aria-selected"), "true");
  titleInput.value = "Mode hors-ligne pour les quiz";
  titleInput.dispatchEvent(new dom.window.Event("input"));
  const parsedSuggestionGithub = new URL(btnGithub.href);
  assert.match(parsedSuggestionGithub.searchParams.get("title"), /\[Suggestion\]/);
  assert.match(parsedSuggestionGithub.searchParams.get("title"), /Mode hors-ligne/);
  assert.match(parsedSuggestionGithub.searchParams.get("labels"), /enhancement/);

  // Tester l'enregistrement direct en base de données via fetch POST /api/feedbacks
  let apiPostPayload = null;
  dom.window.fetch = async (url, options) => {
    if (url === "/api/feedbacks" && options && options.method === "POST") {
      apiPostPayload = JSON.parse(options.body);
      return {
        ok: true,
        json: async () => ({
          id: 42,
          feedback_type: apiPostPayload.feedback_type,
          category: apiPostPayload.category,
          title: apiPostPayload.title,
          description: apiPostPayload.description,
          created_at: "2026-10-12T16:40:00Z",
        }),
      };
    }
    return { ok: true, json: async () => [] };
  };

  titleInput.value = "Widget calendrier sur écran d'accueil";
  descInput.value = "Avoir un widget direct sur Android.";
  click(doc, "#btn-submit-db");

  await new Promise((r) => setImmediate(r));

  assert.ok(apiPostPayload, "POST /api/feedbacks should have been called");
  assert.equal(apiPostPayload.title, "Widget calendrier sur écran d'accueil");
  assert.equal(apiPostPayload.feedback_type, "suggestion");
  assert.match(
    doc.querySelector("#feedback-status-msg").textContent,
    /base de données.*#42/,
  );

  // Vérifier la réinitialisation après enregistrement en base
  assert.equal(titleInput.value, "");
  assert.equal(descInput.value, "");

  // Tester le bouton copier
  titleInput.value = "Mode hors-ligne pour les quiz";
  titleInput.dispatchEvent(new dom.window.Event("input"));
  let copiedText = null;
  dom.window.navigator.clipboard = {
    writeText: async (text) => {
      copiedText = text;
    },
  };
  click(doc, "#btn-copy-feedback");
  return Promise.resolve().then(() => {
    assert.ok(copiedText, "Copied text should not be null");
    assert.match(copiedText, /\[Suggestion\]/);
    dom.window.close();
  });
});

