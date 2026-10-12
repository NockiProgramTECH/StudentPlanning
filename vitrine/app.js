(() => {
  "use strict";
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [
    ...root.querySelectorAll(selector),
  ];
  const icon = (name) =>
    `<svg aria-hidden="true"><use href="#i-${name}"/></svg>`;
  const reducedMotion = window.matchMedia?.(
    "(prefers-reduced-motion: reduce)",
  ).matches;

  $("#year").textContent = String(new Date().getFullYear());

  // Scroll entrances are optional; a script or browser failure never hides content.
  if ("IntersectionObserver" in window && !reducedMotion) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08 },
    );
    document.documentElement.classList.add("motion-ready");
    $$(".reveal").forEach((element) => observer.observe(element));
  }

  const menuButton = $(".menu-toggle");
  const menu = $("#main-nav");
  function closeMenu() {
    menu.classList.remove("open");
    menuButton.setAttribute("aria-expanded", "false");
    menuButton.setAttribute("aria-label", "Ouvrir le menu");
  }
  menuButton.addEventListener("click", () => {
    const isOpen = menu.classList.toggle("open");
    menuButton.setAttribute("aria-expanded", String(isOpen));
    menuButton.setAttribute(
      "aria-label",
      isOpen ? "Fermer le menu" : "Ouvrir le menu",
    );
  });
  $$("a", menu).forEach((link) => link.addEventListener("click", closeMenu));
  document.addEventListener("click", (event) => {
    if (!menu.contains(event.target) && !menuButton.contains(event.target))
      closeMenu();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && menu.classList.contains("open")) {
      closeMenu();
      menuButton.focus();
    }
  });

  // All displayed courses are deliberately fictitious, not the real university PDF.
  const days = [
    {
      short: "Lun",
      day: "LUNDI",
      date: 12,
      courses: [
        {
          time: "08:00",
          end: "10:00",
          name: "Algorithmique",
          room: "Salle B12",
        },
        {
          time: "14:00",
          end: "16:00",
          name: "Bases de données",
          room: "Salle C03",
        },
      ],
    },
    {
      short: "Mar",
      day: "MARDI",
      date: 13,
      courses: [
        {
          time: "08:00",
          end: "10:00",
          name: "Réseaux informatiques",
          room: "Salle A04",
        },
        {
          time: "14:00",
          end: "16:00",
          name: "Mathématiques",
          room: "Salle B12",
        },
      ],
    },
    {
      short: "Mer",
      day: "MERCREDI",
      date: 14,
      courses: [
        {
          time: "10:00",
          end: "12:00",
          name: "Transmission des signaux",
          room: "Salle A02",
        },
      ],
    },
    {
      short: "Jeu",
      day: "JEUDI",
      date: 15,
      courses: [
        {
          time: "08:00",
          end: "10:00",
          name: "Systèmes d’exploitation",
          room: "Salle C03",
        },
      ],
    },
    {
      short: "Ven",
      day: "VENDREDI",
      date: 16,
      courses: [
        {
          time: "10:00",
          end: "12:00",
          name: "Électronique analogique",
          room: "Salle A02",
        },
      ],
    },
  ];

  $$("[data-hero-day]").forEach((button) =>
    button.addEventListener("click", () => {
      const day = days[Number(button.dataset.heroDay)];
      const course = day.courses[0];
      $$("[data-hero-day]").forEach((item) => {
        const active = item === button;
        item.classList.toggle("active", active);
        item.setAttribute("aria-pressed", String(active));
      });
      $(".phone-greeting > span").textContent =
        `${day.day} ${day.date} OCTOBRE`;
      $("#hero-course h4").textContent = course.name;
      $("#hero-course .course-time").textContent =
        `${course.time} — ${course.end}`;
      $("#hero-course .course-room").textContent = `${course.room} · L2 SIR`;
    }),
  );

  const stepViews = [
    `<div class="preview-top"><b>STUDIA / IMPORT</b><span>01 — 03</span></div><h3 class="preview-heading">Le point de départ ?<br>Ton PDF.</h3><p class="preview-description">Sélectionne ton emploi du temps.<br>On t’aide à y voir plus clair.</p><div class="upload-zone">${icon("file")}<b>emploi_du_temps.pdf</b><span>PDF textuel · L2 SIR · Exemple fictif</span></div><div class="preview-meta">${icon("shield")}Tu vérifies toujours avant d’enregistrer.</div><div class="preview-action"><span>Passer à la vérification</span>${icon("arrow")}</div>`,
    `<div class="preview-top"><b>STUDIA / VÉRIFICATION</b><span>02 — 03</span></div><h3 class="preview-heading">Le dernier mot,<br>c’est toujours toi.</h3><p class="preview-description">Matière, salle, horaire : les cours extraits<br>restent à vérifier avant validation.</p><div class="preview-courses"><div class="preview-course"><div><b>Algorithmique</b><small>Lundi · 08:00 – 10:00 · Salle B12</small></div>${icon("check")}</div><div class="preview-course"><div><b>Réseaux informatiques</b><small>Mardi · 08:00 – 10:00 · Salle A04</small></div>${icon("check")}</div></div><div class="preview-action"><span>Valider mon planning</span>${icon("arrow")}</div>`,
    `<div class="preview-top"><b>STUDIA / C’EST PARTI</b><span>03 — 03</span></div><div class="preview-success">${icon("check")}</div><h3 class="preview-heading preview-center">Tout est à sa place.</h3><p class="preview-description preview-center">Ton planning est enregistré sur ton téléphone.<br>Tu peux maintenant organiser tes révisions.</p><div class="preview-metrics"><div><b>7</b><span>cours cette semaine</span></div><div><b>50 min</b><span>un pas pour progresser</span></div></div><div class="preview-meta">${icon("wifi")}Planning consultable même hors ligne.</div>`,
  ];
  function selectStep(index) {
    $$("[data-step]").forEach((button, position) => {
      const active = index === position;
      button.classList.toggle("active", active);
      button.setAttribute("aria-selected", String(active));
      button.tabIndex = active ? 0 : -1;
    });
    const panel = $("#step-panel");
    panel.innerHTML = `<div class="tab-enter">${stepViews[index]}</div>`;
    panel.setAttribute("aria-labelledby", `step-${index}`);
  }
  $$("[data-step]").forEach((button) =>
    button.addEventListener("click", () =>
      selectStep(Number(button.dataset.step)),
    ),
  );
  selectStep(0);

  // WAI-ARIA tab keyboard navigation, shared by both tab sets.
  $$('[role="tablist"]').forEach((list) =>
    list.addEventListener("keydown", (event) => {
      const vertical = list.getAttribute("aria-orientation") === "vertical";
      const nextKey = vertical ? "ArrowDown" : "ArrowRight";
      const prevKey = vertical ? "ArrowUp" : "ArrowLeft";
      if (![nextKey, prevKey, "Home", "End"].includes(event.key)) return;
      const tabs = $$('[role="tab"]', list);
      const current = tabs.indexOf(document.activeElement);
      if (current === -1) return;
      event.preventDefault();
      let next =
        event.key === nextKey
          ? (current + 1) % tabs.length
          : (current - 1 + tabs.length) % tabs.length;
      if (event.key === "Home") next = 0;
      if (event.key === "End") next = tabs.length - 1;
      tabs[next].click();
      tabs[next].focus();
    }),
  );

  const demo = $("#demo-dialog");
  let lastFocusedElement;
  let activeDemo = "planning";
  let demoDay = 1;
  let completedRevisions = new Set();
  let selectedAnswer = null;

  function openDialog(dialog, trigger) {
    lastFocusedElement = trigger;
    dialog.showModal();
    document.body.classList.add("modal-open");
  }
  $$("dialog").forEach((dialog) => {
    $(".close-dialog", dialog).addEventListener("click", () => dialog.close());
    dialog.addEventListener("close", () => {
      document.body.classList.remove("modal-open");
      if (lastFocusedElement?.isConnected) lastFocusedElement.focus();
    });
    dialog.addEventListener("click", (event) => {
      if (event.target !== dialog) return;
      const rect = dialog.getBoundingClientRect();
      if (
        event.clientX < rect.left ||
        event.clientX > rect.right ||
        event.clientY < rect.top ||
        event.clientY > rect.bottom
      )
        dialog.close();
    });
  });
  $$("[data-open-demo]").forEach((trigger) =>
    trigger.addEventListener("click", () => {
      demoDay = 1;
      completedRevisions = new Set();
      selectedAnswer = null;
      selectDemo("planning");
      openDialog(demo, trigger);
    }),
  );
  $("[data-open-privacy]").addEventListener("click", (event) =>
    openDialog($("#privacy-dialog"), event.currentTarget),
  );

  function renderPlanning() {
    const day = days[demoDay];
    return `<div class="demo-panel-heading"><h3>Une semaine bien à toi.</h3><span>12 – 16 octobre · L2 SIR</span></div><div class="demo-days" aria-label="Jours du planning fictif">${days.map((entry, index) => `<button data-demo-day="${index}" aria-pressed="${index === demoDay}">${entry.short} <b>${entry.date}</b></button>`).join("")}</div><div id="demo-day-courses" aria-live="polite">${renderCourses(day)}</div>`;
  }
  function renderCourses(day) {
    return day.courses
      .map(
        (course) =>
          `<article class="demo-course"><time>${course.time}</time><div><h4>${course.name}</h4><p>${course.time} – ${course.end} · ${course.room}</p></div>${icon("book")}</article>`,
      )
      .join("");
  }
  const revisions = [
    { name: "Algorithmique", detail: "Ce soir · 20:00 – 20:50" },
    { name: "Réseaux informatiques", detail: "Demain · 09:00 – 09:50" },
    { name: "Transmission des signaux", detail: "Samedi · 14:00 – 14:50" },
  ];
  function renderRevisions() {
    return `<div class="demo-panel-heading"><h3>À ton rythme, vraiment.</h3><span>Un exemple de programme</span></div><p class="demo-subtitle">Coche une séance terminée. Ici, le suivi reste dans cette démo.</p>${revisions.map((revision, index) => `<label class="demo-revision-item"><input type="checkbox" data-revision="${index}" ${completedRevisions.has(index) ? "checked" : ""}><span><b>${revision.name}</b><small>${revision.detail}</small></span></label>`).join("")}<div class="revision-progress"><progress max="3" value="${completedRevisions.size}" aria-label="Séances terminées"></progress><span id="revision-count" aria-live="polite">${completedRevisions.size} / 3 séances terminées</span></div>`;
  }
  const answers = [
    "Le signal ne peut prendre que deux valeurs.",
    "Le signal varie de façon continue dans le temps.",
    "Le signal ne contient aucune information.",
  ];
  function renderQuiz() {
    return `<div class="quiz-category">${icon("spark")} TRANSMISSION DES SIGNAUX · SECTION 1</div><h3 class="demo-question">Qu’est-ce qui caractérise un signal analogique ?</h3><div class="quiz-choices">${answers.map((answer, index) => `<button data-answer="${index}"><span class="answer-letter">${"ABC"[index]}</span>${answer}</button>`).join("")}</div><div id="quiz-result" aria-live="polite"></div>`;
  }
  function updateQuizResult() {
    $$("[data-answer]").forEach((button) => {
      const index = Number(button.dataset.answer);
      button.disabled = selectedAnswer !== null;
      button.classList.toggle(
        "correct",
        selectedAnswer !== null && index === 1,
      );
      button.classList.toggle(
        "incorrect",
        selectedAnswer === index && index !== 1,
      );
    });
    if (selectedAnswer === null) {
      $("#quiz-result").innerHTML = "";
      return;
    }
    const correct = selectedAnswer === 1;
    $("#quiz-result").innerHTML =
      `<div class="quiz-feedback"><b>${correct ? "Exactement. Le déclic est là !" : "Pas tout à fait. On reprend ensemble."}</b>Un signal analogique peut prendre une infinité de valeurs et varie de manière continue. Contrairement à un signal numérique, il n’est pas limité à des niveaux discrets.<br><small>Exemple pédagogique fictif · Dans l’application, la référence renvoie à une page de ton support.</small></div><button class="quiz-reset" data-reset-quiz>Recommencer la question ↗</button>`;
  }
  function selectDemo(tab) {
    activeDemo = tab;
    $$("[data-demo-tab]").forEach((button) => {
      const active = button.dataset.demoTab === tab;
      button.setAttribute("aria-selected", String(active));
      button.tabIndex = active ? 0 : -1;
    });
    const panel = $("#demo-panel");
    panel.setAttribute("aria-labelledby", `demo-tab-${tab}`);
    panel.innerHTML = `<div class="tab-enter">${tab === "planning" ? renderPlanning() : tab === "revisions" ? renderRevisions() : renderQuiz()}</div>`;
    if (tab === "quiz") updateQuizResult();
  }
  $$("[data-demo-tab]").forEach((button) =>
    button.addEventListener("click", () => selectDemo(button.dataset.demoTab)),
  );
  $("#demo-panel").addEventListener("click", (event) => {
    const dayButton = event.target.closest("[data-demo-day]");
    if (dayButton) {
      demoDay = Number(dayButton.dataset.demoDay);
      $$("[data-demo-day]").forEach((button) =>
        button.setAttribute("aria-pressed", String(button === dayButton)),
      );
      $("#demo-day-courses").innerHTML = renderCourses(days[demoDay]);
    }
    const answerButton = event.target.closest("[data-answer]");
    if (answerButton && selectedAnswer === null) {
      selectedAnswer = Number(answerButton.dataset.answer);
      updateQuizResult();
      $("[data-reset-quiz]").focus({ preventScroll: true });
    }
    if (event.target.closest("[data-reset-quiz]")) {
      selectedAnswer = null;
      updateQuizResult();
      $("[data-answer]").focus({ preventScroll: true });
    }
  });
  $("#demo-panel").addEventListener("change", (event) => {
    if (!event.target.matches("[data-revision]")) return;
    const index = Number(event.target.dataset.revision);
    if (event.target.checked) completedRevisions.add(index);
    else completedRevisions.delete(index);
    $(".revision-progress progress").value = completedRevisions.size;
    $("#revision-count").textContent =
      `${completedRevisions.size} / 3 séances terminées`;
  });
  selectDemo(activeDemo);
})();
