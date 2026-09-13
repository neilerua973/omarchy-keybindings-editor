// Builds the `target` object bin/keybindings-write expects, and the
// shared "which unbound keys can receive a brand-new shortcut" rule used
// by Keyboard.qml. Kept separate from BindingsData.js (parsing/grouping)
// and KeyCapture.js (raw Qt key -> id mapping) since this is specifically
// about constructing a write payload.

var ASSIGNABLE_KEY_RE = /^([A-Z0-9]|F([1-9]|1[0-2]))$/

function isAssignableKeyId(id) {
  return ASSIGNABLE_KEY_RE.test(String(id || ""))
}

// Matches helpers.lua's shell_quote (single-quote wrap, escaping embedded
// single quotes as '\'') — used for the app id inside the gtk-launch
// command line below, not for Lua-string escaping (bin/keybindings-write
// does that on its own once it receives target.value).
function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

// Mirrors how Omarchy's own app launcher starts apps (see
// AppLibrary.qml's launch()): gtk-launch resolves the desktop id the same
// way regardless of Exec= field codes or ids containing spaces.
function launchTargetFor(desktopId) {
  return { kind: "launch", value: "gtk-launch " + shellQuote(String(desktopId) + ".desktop") }
}

function webappTargetFor(url) {
  return { kind: "webapp", value: String(url) }
}

function execTargetFor(command) {
  return { kind: "exec", value: String(command) }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    isAssignableKeyId: isAssignableKeyId,
    shellQuote: shellQuote,
    launchTargetFor: launchTargetFor,
    webappTargetFor: webappTargetFor,
    execTargetFor: execTargetFor
  }
}
