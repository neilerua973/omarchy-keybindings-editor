import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string keyId: ""
  property string label: ""
  property string sublabel: ""
  property string keyState: "unbound" // "unbound" | "bound" | "active-modifier"
  // True for an unbound, non-modifier key that can receive a brand-new
  // shortcut via the app/webapp picker (see WriteTarget.isAssignableKeyId
  // and Keyboard.qml's allowAssign).
  property bool assignable: false

  signal activated()

  readonly property bool isActiveModifier: keyState === "active-modifier"
  readonly property bool isBound: keyState === "bound"
  readonly property bool _hot: assignable && mouseArea.containsMouse

  radius: Style.cornerRadius
  color: isActiveModifier
    ? Color.accent
    : (isBound ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent)
               : Style.normalFillFor(Color.foreground, Color.accent, Color.urgent))
  border.color: isActiveModifier
    ? Color.accent
    : (isBound ? Style.selectedBorderFor(Color.foreground, Color.accent, Color.urgent)
               : (_hot ? Color.accent : Style.normalBorderFor(Color.foreground, Color.accent, Color.urgent)))
  border.width: Style.normalBorderWidth

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: root.assignable
    enabled: root.isBound || root.isActiveModifier || root.assignable
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activated()
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.xxs
    width: parent.width - Style.space(4)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: root.isActiveModifier ? Color.background : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: root.isActiveModifier
      elide: Text.ElideRight
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
    }

    Text {
      visible: root.sublabel.length > 0
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.sublabel
      color: root.isActiveModifier ? Color.background : Color.accent
      font.family: Style.font.family
      font.pixelSize: Math.max(1, Style.font.caption - 2)
      elide: Text.ElideRight
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
