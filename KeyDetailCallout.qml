import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool open: false
  property string keyLabel: ""
  property var bindings: []
  property real anchorY: 0        // clicked key's vertical center, in root's coordinate space
  property real railX: 0          // left edge of the sidebar column, in root's coordinate space
  property real railWidth: Style.space(320)
  property real railTop: 0
  property real railBottom: 0

  // Rebind support. recordingBinding is one of the objects in `bindings`
  // (reference equality, valid for the lifetime of one open popup) while
  // the panel is waiting for a new key chord; null otherwise.
  property var recordingBinding: null
  property string recordingError: ""

  // Assign support (pick an app/webapp for this key — either replacing an
  // existing exec binding's action, or filling in a previously-unbound
  // key). Only one of these is ever true at once; the panel drives which.
  property bool assigning: false
  property string assignError: ""
  property var appOptions: []   // [{ value: desktopId, label: name, description }]
  property string assignKind: "app" // "app" | "webapp", local UI-only state

  signal dismissRequested()
  signal rebindRequested(var binding)
  signal cancelRebindRequested()
  signal changeAppRequested(var binding)
  signal confirmAppRequested(string desktopId, string appName)
  signal confirmWebappRequested(string name, string url)
  signal cancelAssignRequested()

  readonly property real _extraRowHeight: Style.space(34)
  readonly property real cardHeight: Math.min(railBottom - railTop,
    root.assigning ? Style.space(340) : Style.space(60) + bindings.length * (Style.space(46) + _extraRowHeight))
  readonly property real cardY: Math.max(railTop, Math.min(anchorY - cardHeight / 2, railBottom - cardHeight))
  readonly property real arrowY: Math.max(Style.space(14), Math.min(anchorY - cardY, cardHeight - Style.space(14)))

  visible: open
  x: railX
  y: cardY
  width: railWidth
  height: cardHeight

  onOpenChanged: if (!open) root.assignKind = "app"

  Canvas {
    id: arrow
    width: Style.space(10)
    height: Style.space(20)
    x: -width + 1
    y: root.arrowY - height / 2
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = Color.popups.border
      ctx.beginPath()
      ctx.moveTo(width, 0)
      ctx.lineTo(0, height / 2)
      ctx.lineTo(width, height)
      ctx.closePath()
      ctx.fill()
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Color.popups.background
    border.color: Color.popups.border
    border.width: Math.max(1, Style.space(1))

    // Catches clicks anywhere on the card so they dismiss the popup
    // instead of falling through to whatever keycap or layer row sits
    // underneath it. Declared BEFORE the content Column so the Column —
    // and any interactive control inside it (Rebind/Change app buttons,
    // the assign picker's fields) — stacks on top and wins hit-testing
    // over this catch-all. Plain Text/blank space inside the Column has
    // no handler of its own, so clicks there still fall through to this
    // MouseArea exactly as before.
    MouseArea {
      anchors.fill: parent
      onClicked: {
        root.recordingBinding = null
        root.recordingError = ""
        root.assigning = false
        root.assignError = ""
        root.dismissRequested()
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.sm

      Text {
        text: root.keyLabel
        color: root.bindings.length > 0 ? Color.accent : Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Repeater {
        model: root.assigning ? [] : root.bindings

        Column {
          required property var modelData
          width: parent.width
          spacing: Style.spacing.xxs

          readonly property bool editable: modelData.dispatcher === "exec"
          readonly property bool isRecording: root.recordingBinding === modelData

          Text {
            text: modelData.description
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            width: parent.width
          }
          Text {
            text: (modelData.mods.length > 0 ? modelData.mods.join(" + ") + " + " : "") + root.keyLabel
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            text: modelData.arg.length > 0 ? modelData.arg : modelData.dispatcher
            color: Qt.darker(Color.popups.text, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }

          Row {
            visible: editable && !isRecording
            spacing: Style.spacing.sm
            Button {
              text: "Rebind"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.rebindRequested(modelData)
            }
            Button {
              text: "Change app"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.changeAppRequested(modelData)
            }
          }

          Column {
            visible: isRecording
            width: parent.width
            spacing: Style.spacing.xxs

            Text {
              text: "Press the new shortcut… (must include Super) — Esc to cancel"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              width: parent.width
            }
            Text {
              visible: root.recordingError.length > 0
              text: root.recordingError
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              width: parent.width
            }
            Button {
              text: "Cancel"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.cancelRebindRequested()
            }
          }
        }
      }

      // Assign picker: pick an installed app or type a webapp name+URL,
      // then bind it to this key. Shown both for a previously-unbound key
      // (bindings.length === 0) and for "Change app" on an existing one.
      Column {
        visible: root.assigning
        width: parent.width
        spacing: Style.spacing.sm

        Row {
          spacing: Style.spacing.sm
          Button {
            text: "Application"
            fontSize: Style.font.caption
            bordered: true
            selected: root.assignKind === "app"
            onClicked: root.assignKind = "app"
          }
          Button {
            text: "Web app"
            fontSize: Style.font.caption
            bordered: true
            selected: root.assignKind === "webapp"
            onClicked: root.assignKind = "webapp"
          }
        }

        SearchableDropdown {
          id: appDropdown
          visible: root.assignKind === "app"
          width: parent.width
          showLabel: false
          placeholderText: "Search installed apps…"
          emptyText: "No matching app"
          options: root.appOptions
          fontFamily: Style.font.family
        }

        Column {
          visible: root.assignKind === "webapp"
          width: parent.width
          spacing: Style.spacing.xs

          TextField {
            id: webappNameField
            width: parent.width
            placeholderText: "Name (e.g. ChatGPT)"
          }
          TextField {
            id: webappUrlField
            width: parent.width
            placeholderText: "https://…"
          }
        }

        Text {
          visible: root.assignError.length > 0
          text: root.assignError
          color: Color.urgent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Row {
          spacing: Style.spacing.sm
          Button {
            text: "Bind"
            fontSize: Style.font.caption
            bordered: true
            onClicked: {
              if (root.assignKind === "app") {
                if (appDropdown.value.length === 0) return
                var opt = null
                for (var i = 0; i < root.appOptions.length; i++) {
                  if (root.appOptions[i].value === appDropdown.value) { opt = root.appOptions[i]; break }
                }
                root.confirmAppRequested(appDropdown.value, opt ? opt.label : appDropdown.value)
              } else {
                if (webappNameField.text.length === 0 || webappUrlField.text.length === 0) return
                root.confirmWebappRequested(webappNameField.text, webappUrlField.text)
              }
            }
          }
          Button {
            text: "Cancel"
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.cancelAssignRequested()
          }
        }
      }

      Text {
        visible: root.recordingBinding === null && !root.assigning
        text: "Press any key or click to close"
        color: Qt.darker(Color.popups.text, 1.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
