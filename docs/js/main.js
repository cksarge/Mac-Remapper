const toggle = document.querySelector(".nav-toggle");
const links = document.querySelector(".nav-links");

if (toggle && links) {
  toggle.addEventListener("click", () => {
    const isOpen = links.getAttribute("data-open") === "true";
    links.setAttribute("data-open", String(!isOpen));
    toggle.setAttribute("aria-expanded", String(!isOpen));
  });

  links.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      links.setAttribute("data-open", "false");
      toggle.setAttribute("aria-expanded", "false");
    });
  });
}

// Show the newest release's version (e.g. "v1.2.0" → "1.2.0") wherever a page marks it, so the
// site never needs editing for a release. The number written in the HTML is the fallback if
// GitHub can't be reached or its rate limit is hit.
const versionSlots = document.querySelectorAll("[data-latest-version]");

if (versionSlots.length > 0) {
  fetch("https://api.github.com/repos/cksarge/Mac-Remapper/releases/latest", {
    headers: { Accept: "application/vnd.github+json" },
  })
    .then((response) => (response.ok ? response.json() : null))
    .then((release) => {
      const version = release?.tag_name?.replace(/^v/, "");
      if (version) {
        versionSlots.forEach((slot) => {
          slot.textContent = version;
        });
      }
    })
    .catch(() => {});
}
