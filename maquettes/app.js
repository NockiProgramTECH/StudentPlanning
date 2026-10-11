/* Prototype only: no network request, PDF extraction, or server persistence. */
const $ = (selector) => document.querySelector(selector);
const escapeHTML = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (char) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        char
      ],
  );
const monday = "2026-10-12";
const lastMonday = "2026-10-05";
const days = [
  "Lundi",
  "Mardi",
  "Mercredi",
  "Jeudi",
  "Vendredi",
  "Samedi",
  "Dimanche",
];
const palette = ["", "violet", "orange"];
const baseCourses = [
  {
    id: 1,
    subject: "Mathématiques",
    day: 1,
    start: "08:30",
    end: "10:00",
    room: "B204",
    teacher: "Mme Laurent",
  },
  {
    id: 2,
    subject: "Algorithmique",
    day: 1,
    start: "10:30",
    end: "12:00",
    room: "Lab 03",
    teacher: "M. Diallo",
    needsReview: true,
  },
  {
    id: 3,
    subject: "Anglais",
    day: 2,
    start: "09:00",
    end: "10:30",
    room: "C112",
    teacher: "",
  },
  {
    id: 4,
    subject: "Bases de données",
    kind: "course",
    deliveryMode: "online",
    day: 2,
    start: "14:00",
    end: "16:00",
    room: "Lab 01",
    teacher: "",
  },
  {
    id: 5,
    subject: "Réseaux",
    kind: "assessment",
    day: 3,
    start: "08:00",
    end: "10:00",
    room: "A103",
    teacher: "",
  },
  {
    id: 6,
    subject: "Architecture",
    day: 4,
    start: "10:00",
    end: "12:00",
    room: "B201",
    teacher: "",
  },
  {
    id: 7,
    subject: "Projet tutoré",
    day: 5,
    start: "13:30",
    end: "16:00",
    room: "Lab 03",
    teacher: "",
  },
];
const previousCourses = [
  { ...baseCourses[0] },
  { ...baseCourses[1], room: "Lab 02", needsReview: false },
  { ...baseCourses[2] },
  { ...baseCourses[4] },
];
const state = {
  screen: "home",
  selectedDay: 1,
  selectedWeek: monday,
  courses: baseCourses.map((c) => ({ ...c })),
  fileName: "Emploi_du_temps_S42.pdf",
  className: "L2 SIR",
  week: monday,
  edited: false,
  validated: false,
};
const screens = [
  ["home", "Accueil"],
  ["import", "Importer un PDF"],
  ["review", "Vérifier les cours"],
  ["planning", "Planning hebdomadaire"],
  ["compare", "Comparer les semaines"],
  ["history", "Historique"],
];
let toastTimer;
function toast(message) {
  const el = $("#toast");
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 3500);
}
function formatted(
  date,
  opts = { day: "numeric", month: "long", year: "numeric" },
) {
  return new Intl.DateTimeFormat("fr-FR", opts).format(
    new Date(date + "T12:00:00"),
  );
}
function icon(name) {
  const icons = {
    home: "⌂",
    import: "↥",
    review: "☑",
    planning: "▦",
    compare: "⇄",
    history: "◷",
  };
  return icons[name] || "✳";
}
function header(title, action = "") {
  return `<header class="app-header"><button class="app-back" data-screen="home" aria-label="Retour à l'accueil">←</button>
    <span class="header-title">${title}</span>${action ? `<span class="header-action">${action}</span>` : ""}</header>`;
}
function courseCard(course, editable = false) {
  const details = [course.room, course.teacher].filter(Boolean).join(" · ");
  const labels = [
    course.kind === "assessment"
      ? '<span class="course-label exam">DEVOIR</span>'
      : "",
    course.deliveryMode === "online"
      ? '<span class="course-label online">EN LIGNE</span>'
      : "",
  ].join("");
  const colorClass =
    course.kind === "assessment"
      ? "red"
      : course.deliveryMode === "online"
        ? "yellow"
        : palette[course.id % 3];
  return `<article class="course-card" ${editable ? `role="button" tabindex="0" data-edit="${course.id}" aria-label="Modifier ${escapeHTML(course.subject)}"` : ""}>
    <span class="stripe ${colorClass}"></span><div class="course-time">${escapeHTML(course.start)}<br><small>${escapeHTML(course.end)}</small></div>
    <div class="course-body"><b>${escapeHTML(course.subject)}</b>${labels}<span>${escapeHTML(details || "Salle non renseignée")}${course.needsReview ? " · À vérifier" : ""}</span></div>
    ${editable ? '<span class="course-arrow" aria-hidden="true">›</span>' : ""}</article>`;
}
function home() {
  const upcoming = state.courses
    .filter((c) => c.day === 1)
    .sort((a, b) => a.start.localeCompare(b.start));
  return `<div class="screen">
    <div class="app-header"><div class="app-logo"><span class="app-logo-icon">✳</span>studia.</div><button class="app-icon-btn" data-screen="history" aria-label="Ouvrir l'historique">◷</button></div>
    <div class="overline">LUNDI 12 OCTOBRE · EXEMPLE</div>
    <h2 class="serif">Votre semaine,<br><em>en toute clarté.</em></h2>
    <p class="lede">Tous vos cours au même endroit, sans rien oublier.</p>
    <span class="tag-demo">✳ &nbsp; DONNÉES DE DÉMONSTRATION</span>
    <div class="hero-card"><span class="tiny">▦ &nbsp; SEMAINE DU 12 OCTOBRE</span><h3>${escapeHTML(state.className)}</h3>
      <p>${state.courses.length} cours cette semaine · Aperçu fictif</p>
      <button data-screen="planning">Voir mon planning &nbsp; →</button></div>
    <div class="section-head"><h3>Aujourd'hui</h3><span>${upcoming.length} cours</span></div>
    ${
      upcoming.length
        ? upcoming
            .slice(0, 3)
            .map((c) => courseCard(c))
            .join("")
        : '<div class="empty">Aucun cours prévu aujourd’hui.</div>'
    }
    <button class="promo" data-screen="import"><span class="promo-icon">↥</span><span><b>Nouveau planning ?</b><small>Découvrir le parcours d'importation</small></span><span class="go">→</span></button>
  </div>`;
}
function importScreen() {
  return `<div class="screen">${header("Importer un planning", "ÉTAPE 1 / 2")}
    <div class="overline">NOUVELLE SEMAINE</div><h2>Un PDF,<br>un planning.</h2>
    <p class="lede">La façon la plus simple de mettre votre emploi du temps au clair.</p>
    <div class="form-step">01 &nbsp; VOTRE DOCUMENT</div>
    <label class="dropzone" for="pdf-file"><span class="round">▤</span><strong id="file-label">${escapeHTML(state.fileName)}</strong>
      <span class="hint">Choisir un autre PDF · 10 Mo maximum</span></label>
    <input id="pdf-file" class="file-input" type="file" accept="application/pdf,.pdf" aria-label="Choisir un PDF">
    <div class="form-step">02 &nbsp; VOTRE CLASSE</div>
    <div class="input-wrap"><span class="input-prefix">♧</span><input id="class-name" class="text-input" aria-label="Votre classe" maxlength="100" value="${escapeHTML(state.className)}" placeholder="Ex. L2 Informatique"></div>
    <div class="form-step">03 &nbsp; SEMAINE CONCERNÉE</div>
    <div class="input-wrap"><span class="input-prefix">▦</span><input id="week-date" class="text-input" type="date" aria-label="Date du lundi" value="${escapeHTML(state.week)}"></div>
    <p class="privacy-note">✳ &nbsp; Maquette interactive : le fichier sélectionné n'est <strong>ni lu, ni analysé, ni envoyé</strong>. Le résultat suivant utilise des cours fictifs.</p>
    <button class="button-primary" data-action="simulate">Voir le résultat simulé &nbsp; →</button>
  </div>`;
}
function review() {
  const courses = [...state.courses].sort(
    (a, b) => a.day - b.day || a.start.localeCompare(b.start),
  );
  let last = 0;
  return `<div class="screen">${header("Vérification", "ÉTAPE 2 / 2")}
    <div class="overline">AVANT DE VALIDER</div><h2>À vous de<br>vérifier.</h2>
    <p class="lede">Touchez un cours pour le corriger. Rien n'est enregistré sur un serveur.</p>
    <div class="warning"><b>⚠ &nbsp; À vérifier dans le PDF</b>Salle du cours d'Algorithmique à confirmer. Les données sont fictives.</div>
    <div class="change-preview"><b>↗ &nbsp; Par rapport à la semaine passée</b><p>3 propositions de changements à vérifier</p><a data-screen="compare" role="button" tabindex="0">Voir la comparaison &nbsp; →</a></div>
    <div class="section-head"><h3>Cours détectés</h3><span>${courses.length} cours</span></div>
    ${
      courses
        .map((c) => {
          const label =
            c.day !== last
              ? `<div class="review-day">${days[c.day - 1].toUpperCase()}</div>`
              : "";
          last = c.day;
          return `${label}<div class="review-row">${courseCard(c, true)}<button class="delete-btn" data-delete="${c.id}" aria-label="Supprimer ${escapeHTML(c.subject)}">×</button></div>`;
        })
        .join("") || '<div class="empty">Aucun cours dans cette maquette.</div>'
    }
    <div class="sticky-action"><button class="button-primary" data-action="validate">✓ &nbsp; Valider l'aperçu</button></div>
  </div>`;
}
function planning() {
  const week = state.selectedWeek;
  const courses = week === monday ? state.courses : previousCourses;
  const dayCourses = courses
    .filter((c) => c.day === state.selectedDay)
    .sort((a, b) => a.start.localeCompare(b.start));
  return `<div class="screen">${header("Mon planning", week === monday ? "L2 INFORMATIQUE" : "SEMAINE PASSÉE")}
    <div class="overline">VOTRE AGENDA</div><h2>Ma semaine.</h2>
    <p class="lede">Du ${formatted(week, { day: "numeric", month: "short" })} au ${formatted(week === monday ? "2026-10-18" : "2026-10-11", { day: "numeric", month: "short", year: "numeric" })}</p>
    <span class="tag-demo">✳ &nbsp; APERÇU FICTIF</span>
    <div class="day-strip" role="group" aria-label="Choisir un jour">${days
      .map((day, i) => {
        const date = new Date(week + "T12:00:00");
        date.setDate(date.getDate() + i);
        return `<button class="day-pill ${state.selectedDay === i + 1 ? "selected" : ""}" data-day="${i + 1}" aria-pressed="${state.selectedDay === i + 1}"><span>${day.slice(0, 3)}</span><strong>${date.getDate()}</strong></button>`;
      })
      .join("")}</div>
    <div class="section-head"><h3>${days[state.selectedDay - 1]}</h3><span>${dayCourses.length} cours</span></div>
    ${dayCourses.map((c) => courseCard(c)).join("") || '<div class="empty">☀<br>Aucun cours prévu ce jour-là.<br>Profitez de votre temps libre !</div>'}
    ${week !== monday ? '<button class="button-secondary" data-action="current-week" style="margin-top:20px">← Revenir à la semaine actuelle</button>' : ""}
  </div>`;
}
function compare() {
  const changes = [
    {
      type: "SALLE MODIFIÉE",
      subject: "Algorithmique",
      detail: "Lab 02  →  Lab 03",
      symbol: "⇄",
      orange: true,
    },
    {
      type: "COURS AJOUTÉ",
      subject: "Bases de données",
      detail: "Nouveau · 14:00–16:00",
      symbol: "+",
      orange: false,
    },
    {
      type: "COURS AJOUTÉ",
      subject: "Projet tutoré",
      detail: "Nouveau · 13:30–16:00",
      symbol: "+",
      orange: false,
    },
  ];
  return `<div class="screen">${header("Comparaison", "SEMAINE N-1")}
    <div class="overline">D'UNE SEMAINE À L'AUTRE</div><h2>Ce qui<br>change.</h2>
    <p class="lede">Comparez avec la semaine précédente, en un coup d'œil.</p>
    <span class="tag-demo">✳ &nbsp; CHANGEMENTS FICTIFS</span>
    <div class="count-panel"><span class="count-icon">⇄</span><div><strong>3 propositions à vérifier</strong><small>Ne remplacez pas le PDF officiel</small></div></div>
    ${changes.map((c) => `<div class="diff-card"><span class="diff-icon ${c.orange ? "orange" : ""}">${c.symbol}</span><div><span class="type">${c.type}</span><b>${c.subject}</b><p>${c.detail}</p></div></div>`).join("")}
    <p class="diff-disclaimer">Ces différences sont des exemples non recalculés après correction. Dans l'application réelle, elles doivent être confirmées à partir des documents officiels.</p>
    <button class="button-secondary" data-screen="review">← Revenir à la vérification</button>
  </div>`;
}
function historyScreen() {
  return `<div class="screen">${header("Historique", "HORS LIGNE")}
    <div class="overline">VOS ARCHIVES</div><h2>Vos semaines.</h2>
    <p class="lede">Retrouvez vos anciens plannings. Ici, les deux semaines sont des exemples.</p>
    <span class="tag-demo">✳ &nbsp; HISTORIQUE FICTIF</span>
    <div class="form-step" style="margin-top:28px">2026 &nbsp; · &nbsp; OCTOBRE</div>
    <button class="history-card" data-week="${monday}"><span class="history-icon">▦</span><span><b>Semaine du 12 octobre</b><small>${escapeHTML(state.className)} · ${state.courses.length} cours</small></span><span class="go">›</span></button>
    <button class="history-card" data-week="${lastMonday}"><span class="history-icon">▦</span><span><b>Semaine du 5 octobre</b><small>L2 SIR · ${previousCourses.length} cours</small></span><span class="go">›</span></button>
    <div class="warning" style="margin-top:26px"><b>✳ &nbsp; Mode maquette</b>Ces semaines sont fictives et ne sont pas sauvegardées sur votre appareil.</div>
  </div>`;
}
const renderers = {
  home,
  import: importScreen,
  review,
  planning,
  compare,
  history: historyScreen,
};
function render() {
  $("#screen-nav").innerHTML = screens
    .map(
      ([id, label], i) =>
        `<button class="screen-link ${id === state.screen ? "active" : ""}" data-screen="${id}" ${id === state.screen ? 'aria-current="page"' : ""}><span class="number">${String(i + 1).padStart(2, "0")}</span><span class="label">${label}</span><span class="arrow">→</span></button>`,
    )
    .join("");
  $("#app").innerHTML = renderers[state.screen]();
  $("#bottom-nav").innerHTML = [
    ["home", "Accueil"],
    ["planning", "Planning"],
    ["history", "Historique"],
  ]
    .map(
      ([id, label]) =>
        `<button class="nav-tab ${id === state.screen ? "active" : ""}" data-screen="${id}" aria-label="${label}"><span class="glyph">${icon(id)}</span><span>${label}</span></button>`,
    )
    .join("");
  $("#app").scrollTop = 0;
}
function navigate(screen) {
  if (!(screen in renderers)) return;
  if (screen === "planning" && state.screen !== "history")
    state.selectedWeek = monday;
  state.screen = screen;
  render();
}
function closeModal() {
  $("#modal-root").replaceChildren();
}
function editCourse(id) {
  const course = state.courses.find((c) => c.id === id);
  if (!course) return;
  $("#modal-root").innerHTML =
    `<div class="modal-backdrop" data-close="true"><div class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <h3 id="modal-title">Corriger ce cours</h3><p>Les modifications restent dans cette maquette.</p>
    <form id="edit-form"><label>Matière<input class="text-input" name="subject" maxlength="120" required value="${escapeHTML(course.subject)}"></label>
      <label>Jour<select class="text-input" name="day">${days.map((day, i) => `<option value="${i + 1}" ${course.day === i + 1 ? "selected" : ""}>${day}</option>`).join("")}</select></label>
      <div class="row"><label>Début<input class="text-input" name="start" type="time" required value="${escapeHTML(course.start)}"></label>
      <label>Fin<input class="text-input" name="end" type="time" required value="${escapeHTML(course.end)}"></label></div>
      <label>Salle<input class="text-input" name="room" maxlength="100" value="${escapeHTML(course.room)}"></label>
      <label>Enseignant<input class="text-input" name="teacher" maxlength="120" value="${escapeHTML(course.teacher)}"></label>
      <div class="row"><label>Type<select class="text-input" name="kind">
        <option value="unknown" ${!course.kind || course.kind === "unknown" ? "selected" : ""}>À déterminer</option>
        <option value="course" ${course.kind === "course" ? "selected" : ""}>Cours</option>
        <option value="assessment" ${course.kind === "assessment" ? "selected" : ""}>Devoir</option>
      </select></label><label>Modalité<select class="text-input" name="deliveryMode">
        <option value="unknown" ${!course.deliveryMode || course.deliveryMode === "unknown" ? "selected" : ""}>À déterminer</option>
        <option value="in_person" ${course.deliveryMode === "in_person" ? "selected" : ""}>Présentiel</option>
        <option value="online" ${course.deliveryMode === "online" ? "selected" : ""}>En ligne</option>
      </select></label></div>
      <p id="edit-error" class="error-msg" role="alert"></p>
      <div class="modal-actions"><button type="button" class="button-secondary" data-close="true">Annuler</button><button type="submit" class="button-primary">Enregistrer</button></div>
    </form></div></div>`;
  $("#edit-form").addEventListener("submit", (event) => {
    event.preventDefault();
    const fields = new FormData(event.target);
    const start = String(fields.get("start"));
    const end = String(fields.get("end"));
    if (start >= end) {
      $("#edit-error").textContent = "L'heure de fin doit être après le début.";
      return;
    }
    Object.assign(course, {
      subject: String(fields.get("subject")).trim(),
      day: Number(fields.get("day")),
      start,
      end,
      room: String(fields.get("room")).trim(),
      teacher: String(fields.get("teacher")).trim(),
      kind: String(fields.get("kind")),
      deliveryMode: String(fields.get("deliveryMode")),
      needsReview: false,
    });
    state.edited = true;
    closeModal();
    render();
    toast("Cours corrigé dans l’aperçu.");
  });
  $('#modal-root input[name="subject"]').focus();
}
document.addEventListener("click", (event) => {
  if (event.target.matches(".modal-backdrop")) {
    closeModal();
    return;
  }
  const button = event.target.closest(
    "[data-close],[data-screen],[data-action],[data-edit],[data-delete],[data-day],[data-week]",
  );
  if (!button) return;
  if (button.dataset.close) {
    closeModal();
    return;
  }
  if (button.dataset.screen) {
    navigate(button.dataset.screen);
    return;
  }
  if (button.dataset.day) {
    state.selectedDay = Number(button.dataset.day);
    render();
    return;
  }
  if (button.dataset.week) {
    state.selectedWeek = button.dataset.week;
    state.selectedDay = 1;
    state.screen = "planning";
    render();
    return;
  }
  if (button.dataset.edit) {
    editCourse(Number(button.dataset.edit));
    return;
  }
  if (button.dataset.delete) {
    state.courses = state.courses.filter(
      (c) => c.id !== Number(button.dataset.delete),
    );
    state.edited = true;
    render();
    toast("Cours retiré de la maquette.");
    return;
  }
  if (button.dataset.action === "current-week") {
    state.selectedWeek = monday;
    state.selectedDay = 1;
    render();
    return;
  }
  if (button.dataset.action === "simulate") {
    if (!state.className.trim()) {
      toast("Saisissez votre classe avant de continuer.");
      $("#class-name").focus();
      return;
    }
    if (!state.week) {
      toast("Choisissez une semaine.");
      return;
    }
    navigate("review");
    toast("Résultat simulé : aucun PDF n’a été analysé.");
    return;
  }
  if (button.dataset.action === "validate") {
    state.validated = true;
    navigate("home");
    toast("Aperçu validé · aucune donnée enregistrée.");
  }
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeModal();
  if (
    (event.key === "Enter" || event.key === " ") &&
    event.target.matches('[data-edit],[role="button"][data-screen]')
  ) {
    event.preventDefault();
    event.target.click();
  }
});
document.addEventListener("input", (event) => {
  if (event.target.id === "class-name") state.className = event.target.value;
  if (event.target.id === "week-date") state.week = event.target.value;
});
document.addEventListener("change", (event) => {
  if (event.target.id !== "pdf-file") return;
  const file = event.target.files[0];
  if (!file) return;
  if (!/\.pdf$/i.test(file.name) || file.size > 10 * 1024 * 1024) {
    toast("Choisissez un PDF de moins de 10 Mo.");
    event.target.value = "";
    return;
  }
  state.fileName = file.name;
  $("#file-label").textContent = file.name;
  toast("Nom du fichier affiché · le contenu ne sera pas lu.");
});
render();
