(() => {
  "use strict";
  const repository = "NockiProgramTECH/StudentPlanning";
  const checkButton = document.querySelector("#beta-check");
  const downloadLink = document.querySelector("#beta-download");
  const status = document.querySelector("#beta-status");
  const details = document.querySelector("#beta-file-details");
  const feedback = document.querySelector("#beta-feedback-link");
  const feedbackBody = [
    "## Mon retour après les essais",
    "Version Studia :",
    "Modèle du téléphone et version Android (sans identifiant personnel) :",
    "Durée d’utilisation :",
    "",
    "### Ce qui m’aide le plus",
    "",
    "### Ce qui bloque ou manque de clarté",
    "Étapes pour reproduire, résultat attendu, résultat observé :",
    "",
    "### Ce que j’aimerais améliorer",
    "",
    "Merci de ne partager aucun code d’accès, secret, e-mail personnel ou document étudiant non anonymisé : ce retour est public.",
  ].join("\n");
  const query = new URLSearchParams({
    title: "Retour bêta Studia",
    body: feedbackBody,
  });
  feedback.href = `https://github.com/${repository}/issues/new?${query}`;

  // No external request on page load, no credentials and no browser storage.
  // A release page is not an APK: enable downloading only for a real listed asset.
  function apkAsset(release) {
    if (
      !release ||
      release.draft ||
      !release.published_at ||
      !(
        release.prerelease === true || /beta|bêta/i.test(release.tag_name || "")
      )
    )
      return null;
    const assets = (Array.isArray(release.assets) ? release.assets : []).filter(
      (asset) => {
        if (
          !asset ||
          typeof asset.name !== "string" ||
          !/\.apk$/i.test(asset.name) ||
          asset.state !== "uploaded" ||
          !Number.isFinite(asset.size) ||
          asset.size <= 0
        )
          return false;
        try {
          const url = new URL(asset.browser_download_url);
          return (
            url.protocol === "https:" &&
            url.hostname === "github.com" &&
            !url.port &&
            !url.username &&
            !url.password &&
            !url.search &&
            !url.hash &&
            url.pathname.startsWith(`/${repository}/releases/download/`) &&
            /\.apk$/i.test(decodeURIComponent(url.pathname))
          );
        } catch (_) {
          return false;
        }
      },
    );
    // Prefer a universal package. Do not choose a random ABI from a split build.
    return (
      assets.find((asset) => asset.name === "studia-beta.apk") ||
      (assets.length === 1 ? assets[0] : null)
    );
  }

  checkButton.addEventListener("click", async () => {
    if (checkButton.disabled) return;
    checkButton.disabled = true;
    checkButton.setAttribute("aria-busy", "true");
    downloadLink.hidden = true;
    downloadLink.removeAttribute("href");
    details.hidden = true;
    status.textContent = "Recherche d’une bêta Android publiée…";
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch(
        `https://api.github.com/repos/${repository}/releases?per_page=30`,
        {
          headers: { Accept: "application/vnd.github+json" },
          credentials: "omit",
          referrerPolicy: "no-referrer",
          cache: "no-store",
          signal: controller.signal,
        },
      );
      if (!response.ok) throw new Error("Release lookup unavailable");
      const releases = await response.json();
      if (!Array.isArray(releases)) throw new Error("Invalid release list");
      const candidates = releases
        .filter(
          (release) =>
            release && Number.isFinite(Date.parse(release.published_at)),
        )
        .sort(
          (a, b) => Date.parse(b.published_at) - Date.parse(a.published_at),
        );
      let found;
      for (const release of candidates) {
        const asset = apkAsset(release);
        if (asset) {
          found = { release, asset };
          break;
        }
      }
      if (!found) {
        status.textContent =
          "Aucun APK bêta téléchargeable automatiquement pour le moment. Consulte les versions officielles ou essaie la démo en attendant.";
        return;
      }
      const { release, asset } = found;
      downloadLink.href = asset.browser_download_url;
      downloadLink.hidden = false;
      details.textContent = `${release.tag_name} · ${asset.name} · ${(asset.size / 1048576).toLocaleString("fr-FR", { maximumFractionDigits: 1 })} Mo`;
      details.hidden = false;
      status.textContent =
        "Une bêta Android est disponible. Télécharge l’APK officiel ci-dessous pour commencer tes essais.";
      downloadLink.focus({ preventScroll: true });
    } catch (_) {
      status.textContent =
        "Impossible de vérifier les versions pour le moment. Consulte les versions officielles ou réessaie plus tard.";
    } finally {
      window.clearTimeout(timeout);
      checkButton.disabled = false;
      checkButton.removeAttribute("aria-busy");
    }
  });
})();
