(() => {
  const supportedExtRegex = /\.(csv|xls|xlsx)$/i;

  function normalizePath(raw) {
    if (!raw) return "";
    let value = raw;
    try {
      value = decodeURIComponent(value);
    } catch (_err) {}
    value = value.replace(/^\/+/, "");
    return value;
  }

  function extractFileFromUrl() {
    const href = window.location.href;
    const candidates = [
      href.match(/[#/]files\/([^?#]+?\.(?:csv|xls|xlsx))(?:[?#]|$)/i),
      href.match(/[?&]file=([^&#]+?\.(?:csv|xls|xlsx))(?:[&#]|$)/i),
      href.match(/[?&]p=([^&#]+?\.(?:csv|xls|xlsx))(?:[&#]|$)/i)
    ];

    for (const match of candidates) {
      if (!match || !match[1]) continue;
      const candidate = normalizePath(match[1]);
      if (supportedExtRegex.test(candidate)) {
        return candidate;
      }
    }

    return "";
  }

  function redirectIfTabularFileSelected() {
    if (window.location.pathname.startsWith("/tabular")) return;
    const file = extractFileFromUrl();
    if (!file) return;
    const target = `/tabular/?file=${encodeURIComponent(file)}`;
    if (window.location.pathname + window.location.search !== target) {
      window.location.replace(target);
    }
  }

  function injectQuickAccessButton() {
    if (window.location.pathname.startsWith("/tabular")) return;
    if (document.getElementById("premyom-tabular-quick-access")) return;
    const btn = document.createElement("a");
    btn.id = "premyom-tabular-quick-access";
    btn.href = "/tabular/";
    btn.textContent = "Éditeur CSV/XLS/XLSX";
    btn.style.position = "fixed";
    btn.style.right = "16px";
    btn.style.bottom = "16px";
    btn.style.zIndex = "2147483647";
    btn.style.padding = "8px 12px";
    btn.style.borderRadius = "8px";
    btn.style.background = "#1677ff";
    btn.style.color = "#fff";
    btn.style.fontWeight = "600";
    btn.style.fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    btn.style.fontSize = "13px";
    btn.style.textDecoration = "none";
    btn.style.boxShadow = "0 2px 10px rgba(0,0,0,0.25)";
    document.body.appendChild(btn);
  }

  function run() {
    redirectIfTabularFileSelected();
    injectQuickAccessButton();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run, { once: true });
  } else {
    run();
  }

  window.addEventListener("hashchange", redirectIfTabularFileSelected);
})();
