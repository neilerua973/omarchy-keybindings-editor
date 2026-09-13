const test = require("node:test")
const assert = require("node:assert/strict")
const KeyboardLayout = require("../KeyboardLayout.js")

test("allKeyIds has no duplicates and includes core keys", () => {
  const ids = KeyboardLayout.allKeyIds()
  assert.equal(new Set(ids).size, ids.length)
  for (const expected of ["Q", "SPACE", "RETURN", "F1", "SUPERLEFT", "XF86AUDIOPLAY", "LEFT", "UP"]) {
    assert.ok(ids.includes(expected), `missing ${expected}`)
  }
})

test("isModifierKeyId is true only for modifier key ids", () => {
  assert.equal(KeyboardLayout.isModifierKeyId("SUPERLEFT"), true)
  assert.equal(KeyboardLayout.isModifierKeyId("CTRLRIGHT"), true)
  assert.equal(KeyboardLayout.isModifierKeyId("Q"), false)
  assert.equal(KeyboardLayout.isModifierKeyId("SPACE"), false)
})

test("every row cell has a positive width", () => {
  for (const row of KeyboardLayout.rows) {
    for (const cell of row) {
      assert.ok(typeof cell.width === "number" && cell.width > 0, JSON.stringify(cell))
    }
  }
})
