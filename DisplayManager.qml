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
    
    pluginId: "displayManager"
    layerNamespacePlugin: "displayManager"

    property var monitors: []
    property bool isLoading: false
    property string outputBuffer: ""
    property var syncedBrightness: ({})
    property var syncedContrast: ({})
    property bool popoutVisible: false
    property var pendingBrightness: null  // Monitor info for brightness to apply after turning on

    // Only sync when popout is visible (saves CPU when closed)
    Timer {
        id: syncTimer
        interval: 1000
        running: root.popoutVisible
        repeat: true
        onTriggered: root.syncSettingsFromStorage()
    }

    function syncSettingsFromStorage() {
        if (!pluginService || monitors.length === 0) return
        
        // Sync Brightness
        var updatedBrightness = {}
        var updatedContrast = {}
        
        for (var i = 0; i < monitors.length; i++) {
            var bKey = "brightness_" + monitors[i].name
            updatedBrightness[bKey] = pluginService.loadPluginData("displayManager", bKey, 50)
            
            var cKey = "contrast_" + monitors[i].name
            updatedContrast[cKey] = pluginService.loadPluginData("displayManager", cKey, 50)
        }
        
        if (JSON.stringify(updatedBrightness) !== JSON.stringify(syncedBrightness)) {
            syncedBrightness = updatedBrightness
        }
        if (JSON.stringify(updatedContrast) !== JSON.stringify(syncedContrast)) {
            syncedContrast = updatedContrast
        }
    }

    function getBrightness(monitorName) {
        var key = "brightness_" + monitorName
        if (syncedBrightness[key] !== undefined) return syncedBrightness[key]
        return 50
    }

    function getContrast(monitorName) {
        var key = "contrast_" + monitorName
        if (syncedContrast[key] !== undefined) return syncedContrast[key]
        return 50
    }

    // --- Layout ---
    popoutWidth: 420
    popoutHeight: {
        var calculated = 100 + (monitors.length * 170)
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
                    cellHeight: 170

                    model: root.monitors

                    delegate: Rectangle {
                        id: card
                        width: monitorList.cellWidth
                        height: 160 
                        radius: 16
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: modelData.enabled ? Theme.withAlpha(Theme.primary, 0.3) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            // Info & Controls
                            Column {
                                width: parent.width - 56 - 32 
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // Header Row: Info + Scale
                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Column {
                                        width: parent.width - 100
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

                                    // Scale Control
                                    Row {
                                        visible: modelData.enabled
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            color: Theme.surfaceContainerHighest
                                            DankIcon { anchors.centerIn: parent; name: "remove"; size: 16; color: Theme.surfaceText }
                                            MouseArea { anchors.fill: parent; onClicked: root.applyScale(modelData.name, Math.max(0.5, modelData.scale - 0.25)) }
                                        }
                                        
                                        StyledText {
                                            text: modelData.scale.toFixed(2) + "x"
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 36
                                            horizontalAlignment: Text.AlignHCenter
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                        
                                        Rectangle {
                                            width: 24; height: 24; radius: 12
                                            color: Theme.surfaceContainerHighest
                                            DankIcon { anchors.centerIn: parent; name: "add"; size: 16; color: Theme.surfaceText }
                                            MouseArea { anchors.fill: parent; onClicked: root.applyScale(modelData.name, Math.min(3.0, modelData.scale + 0.25)) }
                                        }
                                    }
                                }

                                // Mode Selector
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    visible: modelData.enabled
                                    DankIcon { name: "settings"; size: 16; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                                    
                                    ComboBox {
                                        id: modeCombo
                                        width: parent.width - 24
                                        height: 30
                                        model: modelData.modes
                                        textRole: "text"
                                        currentIndex: modelData.currentModeIndex
                                        
                                        delegate: ItemDelegate {
                                            width: modeCombo.width
                                            contentItem: Text {
                                                text: modelData.text
                                                color: Theme.surfaceText
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                color: modeCombo.highlightedIndex === index ? Theme.primaryContainer : "transparent"
                                            }
                                        }

                                        contentItem: Text {
                                            leftPadding: 10
                                            rightPadding: modeCombo.indicator.width + modeCombo.spacing
                                            text: modeCombo.displayText
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        background: Rectangle {
                                            implicitWidth: 120
                                            implicitHeight: 30
                                            color: Theme.surfaceContainerHighest
                                            radius: 4
                                        }
                                        
                                        onActivated: (index) => {
                                            var m = modelData.modes[index]
                                            root.applyMode(modelData.name, m.width, m.height, m.refresh)
                                        }
                                    }
                                }

                                // Brightness Slider
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    DankIcon { name: "brightness_6"; size: 16; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                                    
                                    Slider {
                                        id: brightSlider
                                        width: parent.width - 24
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

                                // Contrast Slider
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    DankIcon { name: "contrast"; size: 16; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                                    
                                    Slider {
                                        id: contrastSlider
                                        width: parent.width - 24
                                        height: 20
                                        from: 0
                                        to: 100
                                        enabled: modelData.enabled
                                        value: root.getContrast(modelData.name)

                                        background: Rectangle {
                                            x: contrastSlider.leftPadding
                                            y: contrastSlider.topPadding + contrastSlider.availableHeight / 2 - height / 2
                                            implicitWidth: 200
                                            implicitHeight: 4
                                            width: contrastSlider.availableWidth
                                            height: implicitHeight
                                            radius: 2
                                            color: Theme.surfaceContainerHighest

                                            Rectangle {
                                                width: contrastSlider.visualPosition * parent.width
                                                height: parent.height
                                                color: modelData.enabled ? Theme.secondary : Theme.outline
                                                radius: 2
                                            }
                                        }

                                        handle: Rectangle {
                                            x: contrastSlider.leftPadding + contrastSlider.visualPosition * (contrastSlider.availableWidth - width)
                                            y: contrastSlider.topPadding + contrastSlider.availableHeight / 2 - height / 2
                                            implicitWidth: 16
                                            implicitHeight: 16
                                            radius: 8
                                            color: contrastSlider.pressed ? Theme.secondary : Theme.surfaceText
                                            border.color: Theme.surfaceContainer
                                        }
                                        
                                        onMoved: contrastTimer.restart()
                                        
                                        Timer {
                                            id: contrastTimer
                                            interval: 300
                                            repeat: false
                                            onTriggered: {
                                                root.applyContrast(
                                                    modelData.name,
                                                    modelData.serial,
                                                    modelData.model,
                                                    contrastSlider.value
                                                )
                                            }
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
                        
                        var modes = []
                        if (info.modes) {
                            modes = info.modes.map(m => ({
                                width: m.width,
                                height: m.height,
                                refresh: m.refresh_rate / 1000.0,
                                text: `${m.width}x${m.height} @ ${(m.refresh_rate / 1000.0).toFixed(2)}Hz`
                            }))
                        }

                        list.push({
                            name: key,
                            serial: info.serial || info.serial_number || "",
                            enabled: info.current_mode !== null && (info.active !== undefined ? info.active : true),
                            model: info.model || key,
                            scale: (info.logical && info.logical.scale) ? info.logical.scale : 1.0,
                            modes: modes,
                            currentModeIndex: info.current_mode !== null ? info.current_mode : -1
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
                    // Sync settings values after monitors are loaded
                    Qt.callLater(root.syncSettingsFromStorage)
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
        // Safeguard: Prevent turning off the last active monitor
        if (currentState) {
            var enabledCount = 0
            for (var i = 0; i < monitors.length; i++) {
                if (monitors[i].enabled) enabledCount++
            }
            if (enabledCount <= 1) return
        }

        Quickshell.execDetached(["niri", "msg", "output", name, currentState ? "off" : "on"])
        
        // If turning on, schedule brightness application after monitor is ready
        if (!currentState) {
            var mon = monitors.find(m => m.name === name)
            if (mon) {
                pendingBrightness = {
                    name: mon.name,
                    serial: mon.serial,
                    model: mon.model,
                    value: getBrightness(mon.name)
                }
                brightnessApplyTimer.restart()
            }
        }
        
        refreshTimer.restart()
    }

    function applyBrightness(monitorName, serial, model, value) {
        var val = Math.round(value)
        var cmd = serial ? `ddcutil setvcp 10 ${val} --sn '${serial}' --noverify`
                 : model  ? `ddcutil setvcp 10 ${val} --model '${model}' --noverify`
                          : `ddcutil setvcp 10 ${val} --noverify`

        Quickshell.execDetached(["sh", "-c", cmd])
        
        if (pluginService) {
            pluginService.savePluginData("displayManager", "brightness_" + monitorName, value)
            syncSettingsFromStorage()
        }
    }

    function applyContrast(monitorName, serial, model, value) {
        var val = Math.round(value)
        var cmd = serial ? `ddcutil setvcp 12 ${val} --sn '${serial}' --noverify`
                 : model  ? `ddcutil setvcp 12 ${val} --model '${model}' --noverify`
                          : `ddcutil setvcp 12 ${val} --noverify`

        Quickshell.execDetached(["sh", "-c", cmd])
        
        if (pluginService) {
            pluginService.savePluginData("displayManager", "contrast_" + monitorName, value)
            syncSettingsFromStorage()
        }
    }

    function applyScale(monitorName, scale) {
        Quickshell.execDetached(["niri", "msg", "output", monitorName, "scale", scale.toString()])
        // Refresh to update the UI with the new scale (though niri might take a moment)
        refreshTimer.restart()
    }

    function applyMode(monitorName, width, height, refresh) {
        var modeStr = `${width}x${height}@${refresh.toFixed(3)}`
        Quickshell.execDetached(["niri", "msg", "output", monitorName, "mode", modeStr])
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 600
        repeat: false
        onTriggered: refreshMonitors()
    }

    // Timer to apply brightness after turning on a monitor (needs delay for monitor to be ready)
    Timer {
        id: brightnessApplyTimer
        interval: 1500  // Wait for monitor to fully turn on before applying brightness
        repeat: false
        onTriggered: {
            if (root.pendingBrightness) {
                root.applyBrightness(
                    root.pendingBrightness.name,
                    root.pendingBrightness.serial,
                    root.pendingBrightness.model,
                    root.pendingBrightness.value
                )
                root.pendingBrightness = null
            }
        }
    }
    
    Component.onCompleted: refreshMonitors()
}