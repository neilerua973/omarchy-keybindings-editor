const test = require("node:test")
const assert = require("node:assert/strict")
const BindingsData = require("../BindingsData.js")
const KeyboardLayout = require("../KeyboardLayout.js")

const sampleBindings = [
  { mods: ["SUPER"], key: "Q", description: "Close window", dispatcher: "killactive", arg: "" },
  { mods: ["SUPER"], key: "F", description: "File manager", dispatcher: "exec", arg: "nautilus" },
  { mods: ["SUPER", "SHIFT"], key: "F", description: "File manager (cwd)", dispatcher: "exec", arg: "nautilus ." },
  { mods: ["ALT"], key: "TAB", description: "Former workspace", dispatcher: "workspace", arg: "previous" },
  { mods: ["SHIFT", "ALT"], key: "TAB", description: "Focus on previous window", dispatcher: "movefocus", arg: "l" },
  { mods: ["SHIFT", "ALT"], key: "TAB", description: "Reveal active window on top", dispatcher: "bringactivetotop", arg: "" }
]

test("groupIntoLayers buckets by canonically-ordered mods and sorts by count desc", () => {
  // Canonical order is SUPER, SHIFT, CTRL, ALT — Hyprland/omarchy's own
  // convention (see bin/keybindings-data's modmask_to_text, Task 4), not
  // alphabetical: plain `.sort()` would give "SHIFT SUPER" and "ALT SHIFT",
  // which is wrong on both counts.
  const layers = BindingsData.groupIntoLayers(sampleBindings)
  assert.deepEqual(layers.map(l => l.modsKey), ["SHIFT ALT", "SUPER", "ALT", "SUPER SHIFT"])
  const shiftAlt = layers.find(l => l.modsKey === "SHIFT ALT")
  assert.equal(shiftAlt.count, 2)
  assert.deepEqual(shiftAlt.mods, ["SHIFT", "ALT"])
})

test("indexByKeyForLayer groups multiple bindings under one key", () => {
  const shiftAlt = BindingsData.groupIntoLayers(sampleBindings).find(l => l.modsKey === "SHIFT ALT")
  const index = BindingsData.indexByKeyForLayer(shiftAlt.bindings)
  assert.equal(index.TAB.length, 2)
})

test("shortLabel takes the first word, capped at 10 chars", () => {
  assert.equal(BindingsData.shortLabel("Close window"), "Close")
  assert.equal(BindingsData.shortLabel("Superduperlongword here"), "Superduper")
  assert.equal(BindingsData.shortLabel("  "), "")
})

test("layerDisplayName maps empty mods to General", () => {
  assert.equal(BindingsData.layerDisplayName(""), "General")
  assert.equal(BindingsData.layerDisplayName("SUPER SHIFT"), "SUPER SHIFT")
})

test("activeModifierKeyIds expands each modifier to both physical keys", () => {
  const ids = BindingsData.activeModifierKeyIds(["SUPER", "SHIFT"], KeyboardLayout)
  assert.deepEqual(ids.sort(), ["SHIFTLEFT", "SHIFTRIGHT", "SUPERLEFT", "SUPERRIGHT"].sort())
})

test("boundKeyStats counts only non-modifier keys", () => {
  const index = BindingsData.indexByKeyForLayer([
    { mods: ["SUPER"], key: "Q", description: "Close window", dispatcher: "killactive", arg: "" }
  ])
  const stats = BindingsData.boundKeyStats(index, KeyboardLayout)
  assert.equal(stats.bound, 1)
  assert.equal(stats.total, KeyboardLayout.allKeyIds().filter(id => !KeyboardLayout.isModifierKeyId(id)).length)
})

test("filterBindings matches key, description, or modifier substrings", () => {
  const results = BindingsData.filterBindings(sampleBindings, "file")
  assert.equal(results.length, 2)
  assert.ok(results.every(b => b.description.toLowerCase().includes("file")))

  const byKey = BindingsData.filterBindings(sampleBindings, "tab")
  assert.equal(byKey.length, 3)

  const byMod = BindingsData.filterBindings(sampleBindings, "shift")
  assert.equal(byMod.length, 3)

  assert.equal(BindingsData.filterBindings(sampleBindings, "  ").length, sampleBindings.length)
})
