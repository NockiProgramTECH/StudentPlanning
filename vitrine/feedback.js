(() => {
  "use strict";

  const repository = "NockiProgramTECH/StudentPlanning";
  const contactEmail = "contact@studia-app.fr";

  const form = document.querySelector("#feedback-form");
  if (!form) return;

  const tabSuggestion = document.querySelector("#tab-suggestion");
  const tabRetour = document.querySelector("#tab-retour");
  const categoryPills = Array.from(document.querySelectorAll(".category-pill"));
  const categoryInput = document.querySelector("#feedback-category");
  const titleInput = document.querySelector("#feedback-title-input");
  const descInput = document.querySelector("#feedback-desc-input");
  const contextInput = document.querySelector("#feedback-context-input");
  const subjectLabel = document.querySelector("#feedback-subject-label");
  const descLabel = document.querySelector("#feedback-desc-label");
  const quickIdeasList = document.querySelector("#quick-ideas-list");
  const quickIdeasBox = document.querySelector("#quick-ideas-box");
  const btnGithub = document.querySelector("#btn-github-issue");
  const btnEmail = document.querySelector("#btn-email-feedback");
  const btnCopy = document.querySelector("#btn-copy-feedback");
  const statusMsg = document.querySelector("#feedback-status-msg");

  let currentType = "suggestion";

  const quickIdeasData = {
    suggestion: [
      {
        tag: "iCal / Google",
        title: "Synchronisation de l’emploi du temps avec Google Agenda ou iCal",
        desc: "Permettre d’exporter ou synchroniser en un clic les cours détectés vers Google Agenda ou Apple iCal pour recevoir les alertes sur tous mes appareils.",
        category: "planning",
      },
      {
        tag: "Widget",
        title: "Widget écran d’accueil Android avec le prochain cours",
        desc: "Avoir un widget compact sur l’écran d’accueil Android indiquant la matière du prochain cours, la salle et l’heure de début sans ouvrir l’application.",
        category: "ui",
      },
      {
        tag: "Mode sombre",
        title: "Thème sombre complet pour réviser le soir",
        desc: "Ajouter un mode sombre soigné pour reposer les yeux lors des révisions nocturnes et économiser la batterie du smartphone.",
        category: "ui",
      },
      {
        tag: "Partage quiz",
        title: "Partage de fiches et quiz entre camarades de promo",
        desc: "Pouvoir exporter ou partager facilement les quiz générés par l’IA avec les autres étudiants de mon groupe de TD ou de ma classe.",
        category: "quiz",
      },
      {
        tag: "Photo planning",
        title: "Importation du planning depuis une photo ou capture d’écran",
        desc: "Permettre d’importer un emploi du temps à partir d’une photo prise avec l’appareil photo ou d’une capture pour les écoles sans PDF propre.",
        category: "planning",
      },
      {
        tag: "Rappels",
        title: "Rappels configurables avant le début d’un cours",
        desc: "Recevoir une notification programmable 15 ou 30 minutes avant le cours pour anticiper le trajet et ne pas être en retard.",
        category: "revisions",
      },
    ],
    retour: [
      {
        tag: "Extraction PDF",
        title: "Certains cours ou horaires ne sont pas reconnus dans mon PDF",
        desc: "Sur mon emploi du temps officiel, plusieurs matières ou créneaux horaires sont mal découpés ou fusionnés lors de l’importation.",
        category: "planning",
      },
      {
        tag: "Notifications",
        title: "Les alertes de révision ne se déclenchent pas à l’heure prévue",
        desc: "Les rappels programmés pour mes séances de révisions n’apparaissent pas dans le volet de notifications de mon téléphone Android.",
        category: "revisions",
      },
      {
        tag: "Affichage mobile",
        title: "Problème d’affichage ou de débordement sur petit écran",
        desc: "Certains textes et boutons de navigation se chevauchent ou sont coupés sur mon modèle de smartphone.",
        category: "ui",
      },
      {
        tag: "Génération quiz",
        title: "Temps d’attente ou erreur lors de la génération sur un long cours",
        desc: "Le traitement du support de cours prend beaucoup de temps ou échoue sur un document PDF volumineux.",
        category: "quiz",
      },
      {
        tag: "Ergonomie",
        title: "Navigation générale et fluidité entre planning et révisions",
        desc: "L’application est intuitive mais le passage entre le planning du jour et les révisions mériterait un raccourci plus direct.",
        category: "autre",
      },
    ],
  };

  const textsByType = {
    suggestion: {
      subjectLabel: "Titre de ta suggestion pour l’application",
      subjectPlaceholder: "Ex : Exporter les cours vers mon calendrier Google ou iCal",
      descLabel: "Description de la fonctionnalité souhaitée",
      descPlaceholder: "Explique ce que tu aimerais voir dans l’application et en quoi cela t’aiderait pendant tes études…",
      githubPrefix: "[Suggestion]",
      emailSubject: "Suggestion de fonctionnalité pour Studia",
      quickLabel: "Suggestions populaires (clique pour pré-remplir) :",
    },
    retour: {
      subjectLabel: "Objet de ton retour ou problème rencontré",
      subjectPlaceholder: "Ex : Erreur d’affichage sur les cours du vendredi",
      descLabel: "Description détaillée de ton retour",
      descPlaceholder: "Décris ce qui s’est passé, le résultat attendu, ou ton avis général sur l’application…",
      githubPrefix: "[Retour]",
      emailSubject: "Retour d’expérience Studia",
      quickLabel: "Exemples de retours fréquents (clique pour pré-remplir) :",
    },
  };

  function selectCategory(cat) {
    if (categoryInput) categoryInput.value = cat;
    categoryPills.forEach((pill) => {
      const isSelected = pill.getAttribute("data-category") === cat;
      pill.classList.toggle("active", isSelected);
      pill.setAttribute("aria-pressed", String(isSelected));
    });
    updateLinks();
  }

  function renderQuickIdeas() {
    if (!quickIdeasList) return;
    const items = quickIdeasData[currentType] || [];
    quickIdeasList.innerHTML = "";
    items.forEach((item) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = "quick-idea-chip";
      const tagSpan = document.createElement("span");
      tagSpan.className = "chip-tag";
      tagSpan.textContent = item.tag;
      const titleSpan = document.createElement("span");
      titleSpan.className = "chip-title";
      titleSpan.textContent = item.title;
      chip.appendChild(tagSpan);
      chip.appendChild(titleSpan);
      chip.addEventListener("click", () => {
        if (titleInput) titleInput.value = item.title;
        if (descInput) descInput.value = item.desc;
        if (item.category) selectCategory(item.category);
        if (titleInput) titleInput.focus();
        showStatus(`Exemple sélectionné : ${item.title}`);
        updateLinks();
      });
      quickIdeasList.appendChild(chip);
    });
  }

  function setType(type) {
    currentType = type === "retour" ? "retour" : "suggestion";
    const isSuggestion = currentType === "suggestion";
    if (tabSuggestion) {
      tabSuggestion.classList.toggle("active", isSuggestion);
      tabSuggestion.setAttribute("aria-selected", String(isSuggestion));
    }
    if (tabRetour) {
      tabRetour.classList.toggle("active", !isSuggestion);
      tabRetour.setAttribute("aria-selected", String(!isSuggestion));
    }

    const config = textsByType[currentType];
    if (subjectLabel) subjectLabel.textContent = config.subjectLabel;
    if (titleInput) titleInput.placeholder = config.subjectPlaceholder;
    if (descLabel) descLabel.textContent = config.descLabel;
    if (descInput) descInput.placeholder = config.descPlaceholder;

    if (quickIdeasBox) {
      const label = quickIdeasBox.querySelector(".quick-ideas-label-text");
      if (label) label.textContent = config.quickLabel;
    }

    renderQuickIdeas();
    updateLinks();
  }

  function buildPayload() {
    const rawTitle = titleInput ? titleInput.value.trim() : "";
    const rawDesc = descInput ? descInput.value.trim() : "";
    const category = categoryInput ? categoryInput.value : "autre";
    const context = contextInput ? contextInput.value.trim() : "";
    const typeLabel = currentType === "suggestion" ? "Suggestion de fonctionnalité" : "Retour d’expérience";

    const title = rawTitle || (currentType === "suggestion" ? "Idée d’amélioration pour Studia" : "Retour d’utilisation");
    const desc = rawDesc || "Aucune description renseignée.";

    const bodyParts = [
      `## ${typeLabel} — Studia`,
      "",
      `**Domaine concerné :** ${category}`,
    ];
    if (context) {
      bodyParts.push(`**Modèle / Version :** ${context}`);
    }
    bodyParts.push(
      "",
      "### Description détaillée",
      desc,
      "",
      "---",
      "_Rappel vie privée : merci de ne partager aucun code d’accès, mot de passe, e-mail personnel ou document étudiant non anonymisé._",
    );

    const formattedTitle = `${textsByType[currentType].githubPrefix} ${title}`;
    const formattedBody = bodyParts.join("\n");

    return {
      title,
      desc,
      category,
      context,
      typeLabel,
      formattedTitle,
      formattedBody,
    };
  }

  function updateLinks() {
    const payload = buildPayload();
    if (btnGithub) {
      const params = new URLSearchParams({
        title: payload.formattedTitle,
        body: payload.formattedBody,
        labels: currentType === "suggestion" ? "enhancement" : "feedback",
      });
      btnGithub.href = `https://github.com/${repository}/issues/new?${params.toString()}`;
    }
    if (btnEmail) {
      const subject = encodeURIComponent(`[Studia] ${payload.formattedTitle}`);
      const body = encodeURIComponent(payload.formattedBody);
      btnEmail.href = `mailto:${contactEmail}?subject=${subject}&body=${body}`;
    }
  }

  function showStatus(message, isSuccess = true) {
    if (!statusMsg) return;
    statusMsg.textContent = message;
    statusMsg.hidden = false;
    statusMsg.className = `feedback-status-msg ${isSuccess ? "success" : "info"}`;
  }

  if (tabSuggestion) {
    tabSuggestion.addEventListener("click", () => setType("suggestion"));
  }
  if (tabRetour) {
    tabRetour.addEventListener("click", () => setType("retour"));
  }

  categoryPills.forEach((pill) => {
    pill.addEventListener("click", () => {
      const cat = pill.getAttribute("data-category");
      if (cat) selectCategory(cat);
    });
  });

  if (titleInput) titleInput.addEventListener("input", updateLinks);
  if (descInput) descInput.addEventListener("input", updateLinks);
  if (contextInput) contextInput.addEventListener("input", updateLinks);

  if (btnGithub) {
    btnGithub.addEventListener("click", () => {
      showStatus("✓ Ticket GitHub prérempli prêt à être envoyé !");
    });
  }

  if (btnEmail) {
    btnEmail.addEventListener("click", () => {
      showStatus("✓ Client e-mail ouvert avec ton message prérempli !");
    });
  }

  if (btnCopy) {
    btnCopy.addEventListener("click", async () => {
      const payload = buildPayload();
      const textToCopy = `${payload.formattedTitle}\n\n${payload.formattedBody}`;
      try {
        if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(textToCopy);
        } else {
          const ta = document.createElement("textarea");
          ta.value = textToCopy;
          ta.style.position = "fixed";
          ta.style.opacity = "0";
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          document.body.removeChild(ta);
        }
        showStatus("✓ Message copié dans le presse-papier !");
      } catch (_) {
        showStatus("Sélectionne le texte ci-dessus pour le copier manuellement.");
      }
    });
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    if (btnGithub) btnGithub.click();
  });

  // Initialisation
  setType("suggestion");
})();
