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

  // Which browser opens a newly bound web app (see bin/webapp-browsers).
  // The panel owns the value so the choice carries across popups within a
  // session; this component only reads it and reports changes back.
  property var browserOptions: []
  property string webappBrowser: "default"

  signal dismissRequested()
  signal rebindRequested(var binding)
  signal cancelRebindRequested()
  signal changeAppRequested(var binding)
  signal confirmAppRequested(string desktopId, string appName)
  signal confirmWebappRequested(string name, string url)
  // Not named webappBrowserChanged: QML already generates that signal for
  // the property above, and redeclaring it is an error.
  signal browserSelected(string value)
  signal cancelAssignRequested()

  readonly property real _extraRowHeight: Style.space(34)
  // The web-app form is the taller of the two assign modes: two text
  // fields plus the "Open with" dropdown, where the app mode has a single
  // searchable field.
  readonly property real cardHeight: Math.min(railBottom - railTop,
    root.assigning
      ? (root.assignKind === "webapp" ? Style.space(400) : Style.space(340))
      : Style.space(60) + bindings.length * (Style.space(46) + _extraRowHeight))
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

          // Rebind reuses modelData.arg verbatim as the new binding's
          // command (see execTargetFor in KeybindingsPanel.applyRebind),
          // so it only makes sense for bindings whose arg already IS a
          // shell command — i.e. dispatcher === "exec". Assigning an app
          // has no such requirement: it always replaces the action
          // outright, so it's offered for every binding regardless of
          // dispatcher (this is what lets a core WM shortcut like
          // movefocus/workspace get an app attached to it).
          readonly property bool rebindable: modelData.dispatcher === "exec"
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
            visible: !isRecording
            spacing: Style.spacing.sm
            Button {
              visible: rebindable
              text: "Rebind"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.rebindRequested(modelData)
            }
            Button {
              text: rebindable ? "Change app" : "Add app"
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

          // Which browser hosts the web app. Worth surfacing because
          // Omarchy's own launcher only recognises Chromium-family
          // browsers: with Zen or Firefox set as the system default, the
          // "Omarchy default" row still opens the web app in Chromium.
          Dropdown {
            id: browserDropdown
            width: parent.width
            label: "Open with"
            options: root.browserOptions
            value: root.webappBrowser
            fontFamily: Style.font.family
            onChanged: function(value) { root.browserSelected(value) }

            // Dropdown assigns to its own `value` on selection, which
            // breaks the binding above. Re-push the panel's value so a
            // later change there (the initial preselect, most of all)
            // still reaches the control.
            Connections {
              target: root
              function onWebappBrowserChanged() { browserDropdown.value = root.webappBrowser }
            }
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
