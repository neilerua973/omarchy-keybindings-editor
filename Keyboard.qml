import QtQuick
import qs.Commons
import "KeyboardLayout.js" as KeyboardLayout
import "BindingsData.js" as BindingsData
import "WriteTarget.js" as WriteTarget

Column {
  id: root

  property var indexByKey: ({})       // keyId -> Binding[], for the currently displayed context
  property var activeModifierIds: []  // keyId[] to render as "active-modifier"
  property real unit: Style.space(38)
  // When true, unbound non-modifier keys become clickable so the panel can
  // offer to assign a brand-new app/webapp shortcut there. The caller sets
  // this to false while searching or while the active layer has no SUPER
  // (see KeybindingsPanel.qml) — a fresh combo always needs SUPER, so
  // offering assignment on a layer that can't produce one would be a dead
  // end.
  property bool allowAssign: false

  // keyItem lets the caller mapToItem() the click position without
  // Keyboard needing to know the outer window's coordinate space.
  // assignable tells the caller whether this was an empty-bindings click
  // on a key that can still receive a new shortcut, vs. a plain
  // unbound/inert key that should keep being a no-op.
  signal keyClicked(string keyId, var bindings, var keyItem, bool assignable)

  spacing: Style.spacing.xs

  function stateFor(keyId) {
    if (root.activeModifierIds.indexOf(keyId) !== -1) return "active-modifier"
    if (root.indexByKey[keyId] && root.indexByKey[keyId].length > 0) return "bound"
    return "unbound"
  }

  function assignableFor(keyId) {
    return root.allowAssign && root.stateFor(keyId) === "unbound" && WriteTarget.isAssignableKeyId(keyId)
  }

  function sublabelFor(keyId) {
    var bindings = root.indexByKey[keyId]
    if (!bindings || bindings.length === 0) return ""
    return BindingsData.shortLabel(bindings[0].description)
  }

  Repeater {
    model: KeyboardLayout.rows

    Row {
      id: rowItem
      required property var modelData
      spacing: Style.spacing.xs

      Repeater {
        model: rowItem.modelData

        Item {
          id: cellItem
          required property var modelData
          width: root.unit * modelData.width
          height: root.unit

          Key {
            anchors.fill: parent
            visible: !cellItem.modelData.spacer
            keyId: cellItem.modelData.spacer ? "" : cellItem.modelData.id
            label: cellItem.modelData.spacer ? "" : cellItem.modelData.label
            keyState: cellItem.modelData.spacer ? "unbound" : root.stateFor(cellItem.modelData.id)
            sublabel: cellItem.modelData.spacer ? "" : root.sublabelFor(cellItem.modelData.id)
            assignable: cellItem.modelData.spacer ? false : root.assignableFor(cellItem.modelData.id)
            onActivated: root.keyClicked(cellItem.modelData.id, root.indexByKey[cellItem.modelData.id] || [], cellItem, root.assignableFor(cellItem.modelData.id))
          }
        }
      }
    }
  }
}
