// Maps a captured Qt.Key_* code to the plugin's restricted rebind
// vocabulary (letters, digits, F1-F12). Returns null for anything else
// (arrows, punctuation, modifier keys held alone, media keys, ...) so the
// panel keeps listening instead of accepting a key this tool can't yet
// round-trip safely through hl.unbind/o.bind (see bin/keybindings-write's
// header comment for why the scope is this narrow).
//
// Qt.Key_A..Z and Qt.Key_0..9 share their numeric values with ASCII
// upper-case letters/digits, so those ranges convert directly.
// Qt.Key_F1 is hardcoded (0x01000030, stable across Qt5/Qt6) rather than
// imported, so this stays a plain, import-free JS module like its
// siblings (BindingsData.js, KeyboardLayout.js) — loadable unmodified
// both as a QML JS import and as a plain Node module for tests.
var KEY_F1 = 0x01000030

function keyNameFor(qtKey) {
  if (qtKey >= 0x41 && qtKey <= 0x5A) return String.fromCharCode(qtKey) // A-Z
  if (qtKey >= 0x30 && qtKey <= 0x39) return String.fromCharCode(qtKey) // 0-9
  if (qtKey >= KEY_F1 && qtKey <= KEY_F1 + 11) return "F" + (qtKey - KEY_F1 + 1) // F1-F12
  return null
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { keyNameFor: keyNameFor }
}
