import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "KeyboardLayout.js" as KeyboardLayout
import "BindingsData.js" as BindingsData
import "KeyCapture.js" as KeyCapture
import "WriteTarget.js" as WriteTarget

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool closingFromHost: false

  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color accent: Color.accent

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    bindingsProc.running = true
    browsersProc.running = true
    noticeMessage = ""
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide("lemechant.keybindings-editor")
    else window.visible = false
  }

  property var bindings: []
  property var layers: []
  property var activeLayer: null
  property var activeIndexByKey: ({})
  property var activeModifierIds: []
  property var calloutInfo: null // null or { keyId, label, bindings, anchorY }
  property string searchQuery: ""
  readonly property var searchResults: BindingsData.filterBindings(root.bindings, root.searchQuery)
  readonly property bool searching: root.searchQuery.trim().length > 0
  readonly property var displayedIndexByKey: root.searching
    ? BindingsData.indexByKeyForLayer(root.searchResults)
    : root.activeIndexByKey
  readonly property var displayedModifierIds: root.searching ? [] : root.activeModifierIds

  // Rebind support (see KeyDetailCallout.qml + bin/keybindings-write).
  property var recordingBinding: null
  property string recordingError: ""

  // Assign support: pick an app/webapp for an existing exec binding
  // ("Change app") or for a previously-unbound key. assignBinding is the
  // existing binding being changed, or null when assigning fresh onto a
  // clicked-but-unbound key (in which case the target combo comes from
  // the currently active layer + calloutInfo.keyId — see
  // currentAssignCombo()).
  property var assignBinding: null
  property bool assigning: false
  property string assignError: ""

  // Which browser opens a web app bound from here (see
  // bin/webapp-browsers for the rows and what each kind writes).
  // Preselected to the system default browser when that browser can host
  // a web app itself: Omarchy's own launcher only recognises the
  // Chromium family, so leaving this on "Omarchy default" would silently
  // open web apps in Chromium on a Zen/Firefox desktop.
  property var browserOptions: []
  property string webappBrowser: "default"

  // One-off notice shown next to the title after a successful write —
  // currently only "a Zen web app was registered while Zen was running",
  // which the callout can't report because it closes on success.
  property bool pendingZenRestartNotice: false
  property string noticeMessage: ""

  function loadBrowsers(raw) {
    var parsed = []
    try {
      parsed = JSON.parse(String(raw || "[]"))
    } catch (e) {
      parsed = []
    }
    root.browserOptions = Array.isArray(parsed) ? parsed : []
    for (var i = 0; i < root.browserOptions.length; i++) {
      if (root.browserOptions[i].isDefault) {
        root.webappBrowser = String(root.browserOptions[i].value)
        return
      }
    }
  }

  function selectedBrowser() {
    for (var i = 0; i < root.browserOptions.length; i++) {
      if (String(root.browserOptions[i].value) === root.webappBrowser) return root.browserOptions[i]
    }
    return null
  }

  // Installed applications, as SearchableDropdown options. Quickshell's
  // DesktopEntries singleton (from `import Quickshell`) already scans
  // /usr/share/applications + ~/.local/share/applications and filters
  // NoDisplay/Hidden — no .desktop parsing of our own needed.
  readonly property var appOptions: {
    var values = (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications.values : []
    var rows = []
    for (var i = 0; i < values.length; i++) {
      var e = values[i]
      if (!e || e.noDisplay) continue
      var name = String(e.name || e.id || "")
      if (!name) continue
      rows.push({ value: e.id, label: name, description: e.genericName || "" })
    }
    rows.sort(function(a, b) { return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0) })
    return rows
  }

  function startRebind(binding) {
    root.recordingBinding = binding
    root.recordingError = ""
  }

  function cancelRebind() {
    root.recordingBinding = null
    root.recordingError = ""
  }

  function handleRecordingKey(event) {
    var key = KeyCapture.keyNameFor(event.key)
    if (!key) return // modifier-only keypress or unsupported key — keep listening
    var mods = []
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER")
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
    if (event.modifiers & Qt.AltModifier) mods.push("ALT")
    if (mods.indexOf("SUPER") === -1) {
      root.recordingError = "Must include Super"
      return
    }
    root.applyRebind(root.recordingBinding, BindingsData.comboString(mods, key))
  }

  function applyRebind(binding, newCombo) {
    root.recordingError = ""
    var combo = BindingsData.comboString(binding.mods, binding.key)
    writeProc.pendingMode = "rebind"
    writeProc.payload = JSON.stringify({
      description: binding.description,
      oldCombo: combo,
      newCombo: newCombo,
      target: WriteTarget.execTargetFor(binding.arg),
      allowRevertShortcut: true
    })
    writeProc.running = true
  }

  function startAssignForBinding(binding) {
    root.assignBinding = binding
    root.assigning = true
    root.assignError = ""
  }

  function startAssignForKey() {
    root.assignBinding = null
    root.assigning = true
    root.assignError = ""
  }

  function cancelAssign() {
    root.assigning = false
    root.assignBinding = null
    root.assignError = ""
  }

  function currentAssignCombo() {
    if (root.assignBinding) return BindingsData.comboString(root.assignBinding.mods, root.assignBinding.key)
    if (root.calloutInfo && root.activeLayer) return BindingsData.comboString(root.activeLayer.mods, root.calloutInfo.keyId)
    return ""
  }

  function confirmAssignApp(desktopId, appName) {
    root.applyAssign(appName, WriteTarget.launchTargetFor(desktopId))
  }

  // Routes a web app to the chosen browser. Zen is the one kind that
  // cannot be expressed as a command line: its web-app window is only
  // chromeless once the tab is registered in the profile, so the binding
  // is written after bin/zen-webapp-create reports the desktop id it
  // created (see onZenWebappResult).
  function confirmAssignWebapp(name, url) {
    var browser = root.selectedBrowser()
    var kind = browser ? String(browser.kind) : "webapp"

    if (kind === "zen") {
      root.assignError = ""
      zenWebappProc.pendingName = name
      zenWebappProc.payload = JSON.stringify({ name: name, url: url })
      zenWebappProc.running = true
      return
    }
    if (kind === "chromium" && browser.exec) {
      root.applyAssign(name, WriteTarget.chromiumAppTargetFor(browser.exec, url))
      return
    }
    root.applyAssign(name, WriteTarget.webappTargetFor(url))
  }

  function onZenWebappResult(text) {
    var lines = String(text || "").trim().split("\n")
    var desktopId = ""
    var restartZen = false
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.indexOf("OK:") === 0) desktopId = line.slice("OK:".length)
      else if (line === "NOTE:restart-zen") restartZen = true
      else if (line.indexOf("ERROR:") === 0) {
        root.assignError = line.slice("ERROR:".length)
        return
      }
    }
    if (!desktopId) {
      root.assignError = "Could not create the Zen web app"
      return
    }
    root.pendingZenRestartNotice = restartZen
    root.applyAssign(zenWebappProc.pendingName, WriteTarget.launchTargetFor(desktopId))
  }

  function applyAssign(description, target) {
    var combo = root.currentAssignCombo()
    if (!combo) {
      root.assignError = "No key selected"
      return
    }
    root.assignError = ""
    writeProc.pendingMode = "assign"
    writeProc.payload = JSON.stringify({
      description: description,
      oldCombo: combo,
      newCombo: combo,
      target: target,
      allowRevertShortcut: false
    })
    writeProc.running = true
  }

  function onWriteResult(text) {
    var trimmed = String(text || "").trim()
    var mode = writeProc.pendingMode
    var zenRestart = root.pendingZenRestartNotice
    root.pendingZenRestartNotice = false
    if (trimmed.indexOf("OK") === 0) {
      root.recordingBinding = null
      root.recordingError = ""
      root.assigning = false
      root.assignBinding = null
      root.assignError = ""
      root.calloutInfo = null
      root.noticeMessage = zenRestart
        ? "Zen web app created — restart Zen for a chromeless window"
        : ""
      bindingsProc.running = true
    } else if (trimmed.indexOf("ERROR:") === 0) {
      var msg = trimmed.slice("ERROR:".length)
      if (mode === "assign") root.assignError = msg
      else root.recordingError = msg
    } else {
      var fallback = "Unexpected error"
      if (mode === "assign") root.assignError = fallback
      else root.recordingError = fallback
    }
  }

  function loadBindings(raw) {
    var parsed = []
    try {
      parsed = JSON.parse(String(raw || "[]"))
    } catch (e) {
      parsed = []
    }
    root.bindings = Array.isArray(parsed) ? parsed : []
    root.layers = BindingsData.groupIntoLayers(root.bindings)
    var preferred = root.activeLayer ? root.activeLayer.modsKey : null
    var stillExists = preferred !== null && root.layers.some(function(l) { return l.modsKey === preferred })
    if (stillExists) root.selectLayer(preferred)
    else if (root.layers.length > 0) root.selectLayer(root.layers[0].modsKey)
  }

  function selectLayer(modsKey) {
    var layer = null
    for (var i = 0; i < root.layers.length; i++) {
      if (root.layers[i].modsKey === modsKey) { layer = root.layers[i]; break }
    }
    if (!layer) return
    root.calloutInfo = null
    root.activeLayer = layer
    root.activeIndexByKey = BindingsData.indexByKeyForLayer(layer.bindings)
    root.activeModifierIds = BindingsData.activeModifierKeyIds(layer.mods, KeyboardLayout)
  }

  Process {
    id: bindingsProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/lemechant.keybindings-editor/bin/keybindings-data"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadBindings(text)
    }
  }

  Process {
    id: writeProc
    property string payload: "{}"
    property string pendingMode: "" // "rebind" | "assign" — which UI state to clear/report into
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/lemechant.keybindings-editor/bin/keybindings-write", payload]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onWriteResult(text)
    }
  }

  Process {
    id: browsersProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/lemechant.keybindings-editor/bin/webapp-browsers"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.loadBrowsers(text)
    }
  }

  Process {
    id: zenWebappProc
    property string payload: "{}"
    property string pendingName: "" // description to bind once the tab exists
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/lemechant.keybindings-editor/bin/zen-webapp-create", payload]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onZenWebappResult(text)
    }
  }

  FloatingWindow {
    id: window
    title: "Keybindings"
    color: root.background
    implicitWidth: Style.space(1040)
    implicitHeight: Style.space(640)
    minimumSize: Qt.size(Style.space(900), Style.space(560))

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide("lemechant.keybindings-editor")
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (root.assigning) {
          // Form-driven (search field / text fields), not a key-chord
          // capture: only intercept Escape here, let every other key
          // reach whatever field currently has focus normally.
          if (event.key === Qt.Key_Escape) {
            root.cancelAssign()
            event.accepted = true
          }
          return
        }
        if (root.recordingBinding !== null) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRebind()
          } else {
            root.handleRecordingKey(event)
          }
          event.accepted = true
          return
        }
        if (root.calloutInfo !== null) {
          root.calloutInfo = null
          event.accepted = true
          return
        }
        if (searchField.activeFocus && event.key === Qt.Key_Escape) {
          root.searchQuery = ""
          searchField.text = ""
          keyCatcher.forceActiveFocus()
          event.accepted = true
        }
      }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: root.calloutInfo !== null || searchField.activeFocus
        onCloseRequested: root.requestClose()
        onTextKey: function(text) { if (text === "q") root.requestClose() }

        Column {
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.lg

          Item {
            width: parent.width
            height: Math.max(titleRow.height, searchField.height)

            Row {
              id: titleRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.md

              Text {
                text: "Keybindings"
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.activeLayer ? BindingsData.layerDisplayName(root.activeLayer.modsKey) : ""
                color: root.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.noticeMessage.length > 0
                text: root.noticeMessage
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            TextField {
              id: searchField
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(240)
              placeholderText: "Search actions or keys"
              text: root.searchQuery
              onTextChanged: root.searchQuery = text
            }
          }

          Item {
            id: bodyArea
            width: parent.width
            height: parent.height - y - legendRow.height - footerRow.height - Style.spacing.lg * 2

            // Plain Item (not a Row/Column) so KeyDetailCallout — mounted
            // here in Task 7 as bodyArea's second child — can free-float
            // with explicit x/y instead of being repositioned by a
            // positioner, while this Row still lays out the keyboard +
            // sidebar normally.
            // Dismiss the detail callout on any click that isn't otherwise
            // consumed by a more specific interactive element (a keycap, a
            // layer row). Declared before bodyRow/detailCallout so it's the
            // bottom-most item in paint order — Qt Quick's hit-testing
            // reaches the topmost/most-specific item under the pointer
            // first, so this only fires for clicks that land on truly
            // uncovered space (or directly on the callout card, which has
            // no MouseArea of its own to intercept the click).
            MouseArea {
              anchors.fill: parent
              enabled: root.calloutInfo !== null
              onClicked: {
                root.recordingBinding = null
                root.recordingError = ""
                root.assigning = false
                root.assignBinding = null
                root.assignError = ""
                root.calloutInfo = null
              }
            }

            Row {
              id: bodyRow
              anchors.fill: parent
              spacing: Style.spacing.panelGap

              Rectangle {
                id: keyboardArea
                width: parent.width * 0.6
                height: parent.height
                color: "transparent"
                border.color: Style.normalBorderColor
                border.width: Style.normalBorderWidth
                radius: Style.cornerRadius
                clip: true

                Flickable {
                  id: keyboardFlickable
                  anchors.fill: parent
                  anchors.margins: Style.spacing.md
                  contentWidth: keyboard.width
                  contentHeight: keyboard.height
                  boundsBehavior: Flickable.StopAtBounds

                  Keyboard {
                    id: keyboard
                    unit: Math.min(Style.space(38), (keyboardFlickable.width - 14 * Style.spacing.xs) / 15)
                    indexByKey: root.displayedIndexByKey
                    activeModifierIds: root.displayedModifierIds
                    // A brand-new shortcut always needs Super (see
                    // bin/keybindings-write); offering assignment on a
                    // layer that doesn't hold Super, or while search
                    // results span multiple layers, would be a dead end.
                    allowAssign: !root.searching && root.activeLayer !== null && root.activeLayer.mods.indexOf("SUPER") !== -1
                    onKeyClicked: function(keyId, bindings, keyItem, assignable) {
                      if ((!bindings || bindings.length === 0) && !assignable) return
                      // keyItem is the clicked Key's own delegate Item (see
                      // Keyboard.qml's keyClicked signal, Task 6). Mapping
                      // through it — rather than through Keyboard's own
                      // coordinate space — is what makes this correct
                      // regardless of the Flickable's scroll offset or
                      // keyboardArea's margins.
                      var pos = keyItem.mapToItem(bodyArea, 0, keyItem.height / 2)
                      root.calloutInfo = { keyId: keyId, label: keyItem.modelData.label, bindings: bindings || [], anchorY: pos.y }
                      if ((!bindings || bindings.length === 0) && assignable) root.startAssignForKey()
                    }
                  }
                }
              }

              Column {
                width: parent.width - keyboardArea.width - Style.spacing.panelGap
                height: parent.height
                spacing: Style.spacing.md

                Text {
                  id: layersHeaderText
                  text: "MODIFIER LAYERS (" + root.layers.length + ")"
                  color: Qt.darker(root.foreground, 1.3)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }

                ListView {
                  id: layersList
                  width: parent.width
                  height: parent.height - layersHeaderText.height - statText.height - Style.spacing.md * 2
                  model: root.layers
                  spacing: Style.spacing.xs
                  clip: true

                  delegate: Rectangle {
                    required property var modelData
                    width: layersList.width
                    height: Style.space(30)
                    radius: Style.cornerRadius
                    color: root.activeLayer && modelData.modsKey === root.activeLayer.modsKey
                      ? Style.selectedFillFor(root.foreground, root.accent, Color.urgent)
                      : "transparent"

                    Row {
                      anchors.fill: parent
                      anchors.margins: Style.spacing.sm
                      Text {
                        width: parent.width - 40
                        text: BindingsData.layerDisplayName(modelData.modsKey)
                        color: root.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                      }
                      Text {
                        text: String(modelData.count)
                        color: root.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.selectLayer(modelData.modsKey)
                    }
                  }
                }

                Text {
                  id: statText
                  text: {
                    var stats = BindingsData.boundKeyStats(root.displayedIndexByKey, KeyboardLayout)
                    var label = root.searching ? "SEARCH RESULTS" : (root.activeLayer ? BindingsData.layerDisplayName(root.activeLayer.modsKey) : "")
                    return label + " — " + stats.bound + " of " + stats.total + " keys bound"
                  }
                  color: Qt.darker(root.foreground, 1.3)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            KeyDetailCallout {
              id: detailCallout
              open: root.calloutInfo !== null
              keyLabel: root.calloutInfo ? root.calloutInfo.label : ""
              bindings: root.calloutInfo ? root.calloutInfo.bindings : []
              anchorY: root.calloutInfo ? root.calloutInfo.anchorY : 0
              railX: keyboardArea.width + Style.spacing.panelGap
              railTop: 0
              railBottom: bodyArea.height
              recordingBinding: root.recordingBinding
              recordingError: root.recordingError
              assigning: root.assigning
              assignError: root.assignError
              appOptions: root.appOptions
              browserOptions: root.browserOptions
              webappBrowser: root.webappBrowser
              onDismissRequested: {
                root.recordingBinding = null
                root.recordingError = ""
                root.assigning = false
                root.assignBinding = null
                root.assignError = ""
                root.calloutInfo = null
              }
              onRebindRequested: function(binding) { root.startRebind(binding) }
              onCancelRebindRequested: root.cancelRebind()
              onChangeAppRequested: function(binding) { root.startAssignForBinding(binding) }
              onConfirmAppRequested: function(desktopId, appName) { root.confirmAssignApp(desktopId, appName) }
              onConfirmWebappRequested: function(name, url) { root.confirmAssignWebapp(name, url) }
              onBrowserSelected: function(value) { root.webappBrowser = value }
              onCancelAssignRequested: root.cancelAssign()
            }
          }

          Row {
            id: legendRow
            width: parent.width
            spacing: Style.spacing.lg

            Row {
              spacing: Style.spacing.sm
              Rectangle { width: Style.space(10); height: Style.space(10); radius: Style.cornerRadius; color: Color.accent }
              Text { text: "Active modifier"; color: Qt.darker(root.foreground, 1.3); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Row {
              spacing: Style.spacing.sm
              Rectangle { width: Style.space(10); height: Style.space(10); radius: Style.cornerRadius; color: Style.selectedFillFor(root.foreground, root.accent, Color.urgent) }
              Text { text: "Bound in this layer"; color: Qt.darker(root.foreground, 1.3); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Row {
              spacing: Style.spacing.sm
              Rectangle {
                width: Style.space(10); height: Style.space(10); radius: Style.cornerRadius
                color: Style.normalFillFor(root.foreground, root.accent, Color.urgent)
                border.color: Style.normalBorderColor
                border.width: Style.normalBorderWidth
              }
              Text { text: "Unbound"; color: Qt.darker(root.foreground, 1.3); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }

          Row {
            id: footerRow
            width: parent.width
            Text {
              text: root.bindings.length + " bindings"
              color: Qt.darker(root.foreground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
