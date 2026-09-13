// Pure grouping/lookup/label logic over the JSON bin/keybindings-data
// produces. No QML dependency — a guarded module.exports at the bottom
// lets this load unmodified as a Node module (for tests) and as a
// plain QML JS import (`import "BindingsData.js" as BindingsData`).

// Hyprland/omarchy's own modifier-precedence order (see
// bin/keybindings-data's modmask_to_text, Task 4) — SUPER first, then
// SHIFT, then CTRL, then ALT. Plain alphabetical order is wrong here:
// it would print "SHIFT SUPER" and "ALT SHIFT" instead of the
// conventional "SUPER SHIFT" and "SHIFT ALT".
var MOD_ORDER = ["SUPER", "SHIFT", "CTRL", "ALT"]

function sortMods(mods) {
  return (mods || []).slice().sort(function(a, b) {
    var ia = MOD_ORDER.indexOf(a)
    var ib = MOD_ORDER.indexOf(b)
    if (ia === -1) ia = MOD_ORDER.length
    if (ib === -1) ib = MOD_ORDER.length
    if (ia !== ib) return ia - ib
    return a < b ? -1 : (a > b ? 1 : 0)
  })
}

function modsKey(mods) {
  return sortMods(mods).join(" ")
}

// The "SUPER + SHIFT + K" form used by Lua o.bind/hl.unbind's first
// argument (see hyprland.md and bindings.lua) — distinct from modsKey,
// which is a plain space-joined grouping key with no "+" and no trailing
// key token.
function comboString(mods, key) {
  var parts = sortMods(mods).concat([key])
  return parts.join(" + ")
}

function groupIntoLayers(bindings) {
  var byKey = {}
  ;(bindings || []).forEach(function(binding) {
    var key = modsKey(binding.mods)
    if (!byKey[key]) byKey[key] = { modsKey: key, mods: sortMods(binding.mods), bindings: [] }
    byKey[key].bindings.push(binding)
  })
  var layers = Object.keys(byKey).map(function(key) {
    var layer = byKey[key]
    layer.count = layer.bindings.length
    return layer
  })
  layers.sort(function(a, b) {
    if (b.count !== a.count) return b.count - a.count
    return a.modsKey < b.modsKey ? -1 : (a.modsKey > b.modsKey ? 1 : 0)
  })
  return layers
}

function indexByKeyForLayer(layerBindings) {
  var index = {}
  ;(layerBindings || []).forEach(function(binding) {
    if (!index[binding.key]) index[binding.key] = []
    index[binding.key].push(binding)
  })
  return index
}

function shortLabel(description) {
  var trimmed = String(description || "").trim()
  if (trimmed.length === 0) return ""
  return trimmed.split(/\s+/)[0].slice(0, 10)
}

function layerDisplayName(key) {
  return key === "" ? "General" : key
}

function activeModifierKeyIds(mods, keyboardLayout) {
  var ids = []
  ;(mods || []).forEach(function(mod) {
    var forMod = keyboardLayout.modifierKeyIds[mod]
    if (forMod) ids = ids.concat(forMod)
  })
  return ids
}

function boundKeyStats(indexByKey, keyboardLayout) {
  var nonModifierIds = keyboardLayout.allKeyIds().filter(function(id) {
    return !keyboardLayout.isModifierKeyId(id)
  })
  var bound = nonModifierIds.filter(function(id) {
    return !!(indexByKey && indexByKey[id] && indexByKey[id].length > 0)
  }).length
  return { bound: bound, total: nonModifierIds.length }
}

function filterBindings(bindings, query) {
  var needle = String(query || "").trim().toLowerCase()
  if (needle.length === 0) return bindings || []
  return (bindings || []).filter(function(binding) {
    if (binding.description.toLowerCase().indexOf(needle) !== -1) return true
    if (binding.key.toLowerCase().indexOf(needle) !== -1) return true
    return modsKey(binding.mods).toLowerCase().indexOf(needle) !== -1
  })
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    modsKey: modsKey,
    comboString: comboString,
    groupIntoLayers: groupIntoLayers,
    indexByKeyForLayer: indexByKeyForLayer,
    shortLabel: shortLabel,
    layerDisplayName: layerDisplayName,
    activeModifierKeyIds: activeModifierKeyIds,
    boundKeyStats: boundKeyStats,
    filterBindings: filterBindings
  }
}
