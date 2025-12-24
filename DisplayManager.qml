import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    
    pluginId: "monitorToggle"
    layerNamespacePlugin: "monitor-toggle"

    property var monitors: []
    property bool isLoading: false
    property string outputBuffer: ""
    property var syncedBrightness: ({})
    property bool popoutVisible: false

    // Only sync when popout is visible (saves CPU when closed)
    Timer {
        id: syncTimer
        interval: 500
        running: root.popoutVisible
        repeat: true
        onTriggered: root.syncBrightnessFromStorage()
    }

    function syncBrightnessFromStorage() {
        if (!pluginService || monitors.length === 0) return
        var updated = {}
        for (var i = 0; i < monitors.length; i++) {
            var key = "brightness_" + monitors[i].name
            updated[key] = pluginService.loadPluginData("monitorToggle", key, 50)
        }
        if (JSON.stringify(updated) !== JSON.stringify(syncedBrightness)) {
            syncedBrightness = updated
        }
    }

    function getBrightness(monitorName) {
        var key = "brightness_" + monitorName
        if (syncedBrightness[key] !== undefined) return syncedBrightness[key]
        return 50
    }

    // --- Layout ---
    popoutWidth: 420
    popoutHeight: {
        var calculated = 100 + (monitors.length * 90)
        if (calculated < 300) return 300
        if (calculated > 750) return 750
        return calculated
    }

    // --- Bar Icons ---
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "desktop_windows"
                size: Theme.iconSize
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "desktop_windows"
                size: Theme.iconSize
                color: root.monitors.some(m => m.enabled) ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // --- Popout Content ---
    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: "Display Manager"
            detailsText: root.isLoading ? "Scanning..." : `${root.monitors.length} connected displays`
            showCloseButton: true

            Component.onCompleted: { root.popoutVisible = true; root.refreshMonitors() }
            Component.onDestruction: root.popoutVisible = false

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutComp.headerHeight - popoutComp.detailsHeight - Theme.spacingXL
                
                // Refresh Button
                DankIcon {
                    name: "refresh"
                    size: 20
                    color: root.isLoading ? Theme.primary : Theme.surfaceVariantText
                    anchors.right: parent.right
                    anchors.rightMargin: 7 
                    anchors.top: parent.top
                    anchors.topMargin: -35
                    z: 50

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshMonitors()
                    }
                    RotationAnimator on rotation {
                        running: root.isLoading
                        from: 0; to: 360; loops: Animation.Infinite; duration: 1000
                    }
                }

                // Monitor List
                DankGridView {
                    id: monitorList
                    visible: !root.isLoading
                    width: parent.width
                    height: parent.height
                    clip: true
                    cellWidth: parent.width
                    cellHeight: 90

                    model: root.monitors

                    delegate: Rectangle {
                        id: card
                        width: monitorList.cellWidth
                        height: 80 
                        radius: 16
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: modelData.enabled ? Theme.withAlpha(Theme.primary, 0.3) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            // Icon
                            Rectangle {
                                width: 48
                                height: 48
                                radius: 14
                                color: modelData.enabled ? Theme.primary : Theme.surfaceContainerHighest
                                anchors.verticalCenter: parent.verticalCenter
                                
                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "desktop_windows"
                                    size: 24
                                    color: modelData.enabled ? Theme.onPrimary : Theme.surfaceVariantText
                                }
                            }

                            // Info & Slider
                            Column {
                                width: parent.width - 48 - 56 - 32 
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Column {
                                    width: parent.width
                                    StyledText {
                                        text: modelData.model
                                        font.weight: Font.Bold
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    StyledText {
                                        text: modelData.name + (modelData.serial ? "" : " (No Serial)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        opacity: 0.8
                                    }
                                }

                                Slider {
                                    id: brightSlider
                                    width: parent.width
                                    height: 20
                                    from: 0
                                    to: 100
                                    enabled: modelData.enabled
                                    value: root.getBrightness(modelData.name)

                                    background: Rectangle {
                                        x: brightSlider.leftPadding
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 4
                                        width: brightSlider.availableWidth
                                        height: implicitHeight
                                        radius: 2
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            width: brightSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: modelData.enabled ? Theme.primary : Theme.outline
                                            radius: 2
                                        }
                                    }

                                    handle: Rectangle {
                                        x: brightSlider.leftPadding + brightSlider.visualPosition * (brightSlider.availableWidth - width)
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 16
                                        implicitHeight: 16
                                        radius: 8
                                        color: brightSlider.pressed ? Theme.primary : Theme.surfaceText
                                        border.color: Theme.surfaceContainer
                                    }
                                    
                                    onMoved: brightnessTimer.restart()
                                    
                                    Timer {
                                        id: brightnessTimer
                                        interval: 300
                                        repeat: false
                                        onTriggered: {
                                            root.applyBrightness(
                                                modelData.name,
                                                modelData.serial,
                                                modelData.model,
                                                brightSlider.value
                                            )
                                        }
                                    }
                                }
                            }

                            // Toggle Switch
                            Rectangle {
                                width: 56
                                height: 32
                                radius: 16
                                color: modelData.enabled ? Theme.primaryContainer : Theme.outlineVariant
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Behavior on color { ColorAnimation { duration: 200 } }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: modelData.enabled ? "check" : "close"
                                    size: 18
                                    color: modelData.enabled ? Theme.onPrimaryContainer : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleMonitor(modelData.name, modelData.enabled)
                                }
                            }
                        }
                    }
                }
                
                // Empty State
                Column {
                    visible: !root.isLoading && root.monitors.length === 0
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    z: 10
                    DankIcon {
                        name: "videocam_off"
                        size: 48
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    StyledText {
                        text: "No displays detected"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }
            }
        }
    }

    // --- Backend Logic ---

    Process {
        id: fetchProcess
        command: ["niri", "msg", "--json", "outputs"]
        stdout: SplitParser { onRead: (chunk) => root.outputBuffer += chunk }
        onExited: (code) => {
            root.isLoading = false
            try {
                if (code === 0 && root.outputBuffer.trim() !== "") {
                    var data = JSON.parse(root.outputBuffer)
                    var list = []
                    
                    for (var key in data) {
                        var info = data[key]
                        list.push({
                            name: key,
                            serial: info.serial || info.serial_number || "",
                            enabled: info.current_mode !== null && info.active !== false,
                            model: info.model || key
                        })
                    }

                    list.sort((a, b) => {
                        return a.name.localeCompare(
                            b.name,
                            undefined,
                            { numeric: true, sensitivity: "base" }
                        )
                    })

                    root.monitors = list
                    // Sync brightness values after monitors are loaded
                    Qt.callLater(root.syncBrightnessFromStorage)
                }
            } catch (e) { console.error(e) }
        }
    }

    function refreshMonitors() {
        isLoading = true
        outputBuffer = ""
        fetchProcess.running = true
    }

    function toggleMonitor(name, currentState) {
        Quickshell.execDetached(["niri", "msg", "output", name, currentState ? "off" : "on"])
        refreshTimer.restart()
    }

    function applyBrightness(monitorName, serial, model, value) {
        var val = Math.round(value)
        var cmd = serial ? `ddcutil setvcp 10 ${val} --sn '${serial}' --noverify`
                 : model  ? `ddcutil setvcp 10 ${val} --model '${model}' --noverify`
                          : `ddcutil setvcp 10 ${val} --noverify`

        Quickshell.execDetached(["sh", "-c", cmd])
        
        if (pluginService) {
            pluginService.savePluginData("monitorToggle", "brightness_" + monitorName, value)
            syncBrightnessFromStorage()
        }
    }

    Timer {
        id: refreshTimer
        interval: 600
        repeat: false
        onTriggered: refreshMonitors()
    }
    
    Component.onCompleted: refreshMonitors()
}