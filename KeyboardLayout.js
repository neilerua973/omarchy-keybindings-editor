// Standard ANSI keyboard layout as rows of cells, in 1u keycap units.
// Ids are upper-case to match the normalized key names emitted by
// bin/keybindings-data. Media row + arrow cluster are stacked as their
// own rows below the main block (a simplification vs. a physical
// keyboard's side-by-side placement) — spec deviation is intentional,
// see docs/superpowers/specs/2026-09-09-keybindings-visualizer-design.md.

var rows = [
  [
    { id: "ESCAPE", label: "Esc", width: 1 },
    { spacer: true, width: 0.5 },
    { id: "F1", label: "F1", width: 1 }, { id: "F2", label: "F2", width: 1 },
    { id: "F3", label: "F3", width: 1 }, { id: "F4", label: "F4", width: 1 },
    { spacer: true, width: 0.25 },
    { id: "F5", label: "F5", width: 1 }, { id: "F6", label: "F6", width: 1 },
    { id: "F7", label: "F7", width: 1 }, { id: "F8", label: "F8", width: 1 },
    { spacer: true, width: 0.25 },
    { id: "F9", label: "F9", width: 1 }, { id: "F10", label: "F10", width: 1 },
    { id: "F11", label: "F11", width: 1 }, { id: "F12", label: "F12", width: 1 }
  ],
  [
    { id: "GRAVE", label: "`", width: 1 },
    { id: "1", label: "1", width: 1 }, { id: "2", label: "2", width: 1 },
    { id: "3", label: "3", width: 1 }, { id: "4", label: "4", width: 1 },
    { id: "5", label: "5", width: 1 }, { id: "6", label: "6", width: 1 },
    { id: "7", label: "7", width: 1 }, { id: "8", label: "8", width: 1 },
    { id: "9", label: "9", width: 1 }, { id: "0", label: "0", width: 1 },
    { id: "MINUS", label: "-", width: 1 }, { id: "EQUAL", label: "=", width: 1 },
    { id: "BACKSPACE", label: "Bksp", width: 2 }
  ],
  [
    { id: "TAB", label: "Tab", width: 1.5 },
    { id: "Q", label: "Q", width: 1 }, { id: "W", label: "W", width: 1 },
    { id: "E", label: "E", width: 1 }, { id: "R", label: "R", width: 1 },
    { id: "T", label: "T", width: 1 }, { id: "Y", label: "Y", width: 1 },
    { id: "U", label: "U", width: 1 }, { id: "I", label: "I", width: 1 },
    { id: "O", label: "O", width: 1 }, { id: "P", label: "P", width: 1 },
    { id: "BRACKETLEFT", label: "[", width: 1 }, { id: "BRACKETRIGHT", label: "]", width: 1 },
    { id: "BACKSLASH", label: "\\", width: 1.5 }
  ],
  [
    { id: "CAPSLOCK", label: "Caps", width: 1.75 },
    { id: "A", label: "A", width: 1 }, { id: "S", label: "S", width: 1 },
    { id: "D", label: "D", width: 1 }, { id: "F", label: "F", width: 1 },
    { id: "G", label: "G", width: 1 }, { id: "H", label: "H", width: 1 },
    { id: "J", label: "J", width: 1 }, { id: "K", label: "K", width: 1 },
    { id: "L", label: "L", width: 1 }, { id: "SEMICOLON", label: ";", width: 1 },
    { id: "APOSTROPHE", label: "'", width: 1 }, { id: "RETURN", label: "Enter", width: 2.25 }
  ],
  [
    { id: "SHIFTLEFT", label: "Shift", width: 2.25 },
    { id: "Z", label: "Z", width: 1 }, { id: "X", label: "X", width: 1 },
    { id: "C", label: "C", width: 1 }, { id: "V", label: "V", width: 1 },
    { id: "B", label: "B", width: 1 }, { id: "N", label: "N", width: 1 },
    { id: "M", label: "M", width: 1 }, { id: "COMMA", label: ",", width: 1 },
    { id: "PERIOD", label: ".", width: 1 }, { id: "SLASH", label: "/", width: 1 },
    { id: "SHIFTRIGHT", label: "Shift", width: 2.75 }
  ],
  [
    { id: "CTRLLEFT", label: "Ctrl", width: 1.25 },
    { id: "SUPERLEFT", label: "Super", width: 1.25 },
    { id: "ALTLEFT", label: "Alt", width: 1.25 },
    { id: "SPACE", label: "Space", width: 6.25 },
    { id: "ALTRIGHT", label: "Alt", width: 1.25 },
    { id: "SUPERRIGHT", label: "Super", width: 1.25 },
    { id: "MENU", label: "Menu", width: 1.25 },
    { id: "CTRLRIGHT", label: "Ctrl", width: 1.25 }
  ],
  [
    { id: "XF86AUDIOPREV", label: "Prev", width: 1.5 },
    { id: "XF86AUDIOPLAY", label: "Play", width: 1.5 },
    { id: "XF86AUDIONEXT", label: "Next", width: 1.5 },
    { spacer: true, width: 0.5 },
    { id: "XF86AUDIOMUTE", label: "Mute", width: 1.5 },
    { id: "XF86AUDIOLOWERVOLUME", label: "Vol-", width: 1.5 },
    { id: "XF86AUDIORAISEVOLUME", label: "Vol+", width: 1.5 }
  ],
  [
    { spacer: true, width: 8 },
    { id: "UP", label: "↑", width: 1 }
  ],
  [
    { spacer: true, width: 7 },
    { id: "LEFT", label: "←", width: 1 },
    { id: "DOWN", label: "↓", width: 1 },
    { id: "RIGHT", label: "→", width: 1 }
  ]
]

var modifierKeyIds = {
  SUPER: ["SUPERLEFT", "SUPERRIGHT"],
  CTRL: ["CTRLLEFT", "CTRLRIGHT"],
  ALT: ["ALTLEFT", "ALTRIGHT"],
  SHIFT: ["SHIFTLEFT", "SHIFTRIGHT"]
}

var _modifierIdSet = null

function _buildModifierIdSet() {
  var set = {}
  for (var name in modifierKeyIds) {
    modifierKeyIds[name].forEach(function(id) { set[id] = true })
  }
  return set
}

function isModifierKeyId(id) {
  if (!_modifierIdSet) _modifierIdSet = _buildModifierIdSet()
  return !!_modifierIdSet[id]
}

function allKeyIds() {
  var ids = []
  rows.forEach(function(row) {
    row.forEach(function(cell) {
      if (!cell.spacer) ids.push(cell.id)
    })
  })
  return ids
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    rows: rows,
    modifierKeyIds: modifierKeyIds,
    isModifierKeyId: isModifierKeyId,
    allKeyIds: allKeyIds
  }
}
