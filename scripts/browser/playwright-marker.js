// Injected by Playwright MCP into every page it controls. Marks the document
// title with an invisible zero-width space so Hyprland can tell agent-driven
// Helium windows apart from the human's own Helium windows. The marker is
// re-applied if the site changes its title, and is invisible in the tab bar.
(() => {
  const MARK = '\u200b';
  const apply = () => {
    const title = document.querySelector('title');
    if (title && !title.textContent.startsWith(MARK)) {
      title.textContent = MARK + title.textContent;
    }
  };
  new MutationObserver(apply).observe(document, {
    childList: true,
    subtree: true,
    characterData: true,
  });
  document.addEventListener('DOMContentLoaded', apply);
  apply();
})();
