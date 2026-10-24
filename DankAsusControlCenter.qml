import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null

    // --- Settings ---
    property int refreshInterval: (pluginData.refreshInterval || 5) * 1000
    property bool showWattage: pluginData.showWattage ?? true
    property bool showDgpuState: pluginData.showDgpuState ?? true
    // Empty = auto-detect (display-class PCI device that is not the boot VGA)
    readonly property string pciAddr: pluginData.pciAddress || ""

    // --- asusctl ---
    property string asusCtlInfo: ""
    property string activeProfile: "Balanced"
    property var supportedPowerProfiles: []
    property int batteryLimit: 100

    // --- cardwire ---
    property string cardwireInfo: ""
    property string cardwireMode: "unknown"
    property var supportedCardwireModes: []
    readonly property bool cardwireAvailable: cardwireInfo.length > 0 && cardwireInfo !== "MISSING"
    readonly property bool asusCtlAvailable: asusCtlInfo.length > 0 && asusCtlInfo !== "MISSING"

    // --- Battery (sysfs) ---
    property string batteryWattage: "..."
    property bool hasBattery: false
    property string acOnline: "..."
    property string batStatus: "..."
    property int batteryLevel: 0
    property int batteryHealthPct: -1
    readonly property bool isOnACPower: acOnline === "1"
    readonly property bool onBattery: !isOnACPower && batStatus !== "Full"

    // --- dGPU (sysfs) ---
    property string dgpuAddr: ""
    property string dgpuState: "..."
    property string gpuRuntimeStatus: "..."
    property string gpuPowerControl: "..."
    readonly property bool dgpuIdle: dgpuState === "D3cold" || dgpuState === "D3" || dgpuState === "D3hot"
    readonly property bool dgpuKnown: dgpuState !== "..." && dgpuState !== "?"
    readonly property color dgpuColor: dgpuKnown && !dgpuIdle && onBattery ? Theme.error : Theme.surfaceText

    // ---------------- asusctl processes ----------------

    Process {
        id: procAsusCtlInfo
        command: ["sh", "-c", "asusctl info 2>/dev/null || echo MISSING"]
        stdout: SplitParser {
            onRead: line => {
                var trimmed = line.trim();
                var match = trimmed.match(/Software version:\s*([\d\.]+)/);
                if (match)
                    root.asusCtlInfo = match[1];
                else if (trimmed === "MISSING")
                    root.asusCtlInfo = "MISSING";
            }
        }
    }

    Process {
        id: procPowerGet
        command: ["asusctl", "profile", "get"]
        stdout: SplitParser {
            onRead: line => {
                var match = line.trim().match(/Active profile:\s*(\w+)/);
                if (match)
                    root.activeProfile = match[1];
            }
        }
    }

    Process {
        id: procProfileList
        command: ["asusctl", "profile", "list"]
        onRunningChanged: {
            if (!running)
                root.supportedPowerProfiles = root.supportedPowerProfiles.filter(p => p.length > 0);
        }
        stdout: SplitParser {
            onRead: line => {
                var clean = line.trim();
                if (clean.length > 0 && !root.supportedPowerProfiles.includes(clean))
                    root.supportedPowerProfiles = root.supportedPowerProfiles.concat([clean]);
            }
        }
    }

    Process {
        id: procPowerSet
        command: ["asusctl", "profile", "set", "Balanced"]
        stderr: SplitParser {
            onRead: line => ToastService.showError("ASUS Error", line)
        }
        onExited: code => {
            if (code === 0)
                procPowerGet.running = true;
        }
    }

    Process {
        id: procBatteryLimitGet
        command: ["asusctl", "battery", "info"]
        stdout: SplitParser {
            onRead: line => {
                var match = line.trim().match(/Current battery charge limit:\s*(\d+)%/);
                if (match)
                    root.batteryLimit = parseInt(match[1]);
            }
        }
    }

    Process {
        id: procBatteryLimitSet
        command: ["asusctl", "battery", "limit", "80"]
        stderr: SplitParser {
            onRead: line => ToastService.showError("Battery Limit Error", line)
        }
        onExited: code => {
            if (code === 0) {
                ToastService.showInfo("Battery", "Charge limit set to " + procBatteryLimitSet.command[3] + "%");
                procBatteryLimitGet.running = true;
            }
        }
    }

    Process {
        id: procBatteryOneShot
        command: ["asusctl", "battery", "oneshot"]
        stderr: SplitParser {
            onRead: line => ToastService.showError("Battery One Shot Error", line)
        }
        onExited: code => {
            if (code === 0)
                ToastService.showInfo("Battery One Shot", "Charging to 100% once, limit resumes after");
        }
    }

    // ---------------- cardwire processes ----------------

    Process {
        id: procCardwireInfo
        command: ["sh", "-c", "cardwire --version 2>/dev/null || echo MISSING"]
        stdout: SplitParser {
            onRead: line => {
                var trimmed = line.trim();
                if (trimmed === "MISSING") {
                    root.cardwireInfo = "MISSING";
                } else {
                    var match = trimmed.match(/([\d]+(?:\.[\d]+)*)/);
                    root.cardwireInfo = match ? match[1] : trimmed;
                }
            }
        }
    }

    // `cardwire get` prints "Current Mode: X" then "Available Mode: a, b, c"
    Process {
        id: procCardwireGet
        command: ["cardwire", "get"]
        stdout: SplitParser {
            onRead: line => {
                var trimmed = line.trim();
                var match = trimmed.match(/current\s+mode:\s*(\S+)/i);
                if (match) {
                    root.cardwireMode = match[1].toLowerCase();
                    return;
                }
                match = trimmed.match(/available\s+modes?:\s*(.+)/i);
                if (match)
                    root.supportedCardwireModes = match[1].split(/,\s*/).map(m => m.trim().toLowerCase()).filter(m => m.length > 0);
            }
        }
    }

    Process {
        id: procCardwireSet
        command: ["cardwire", "set", "hybrid"]
        stderr: SplitParser {
            onRead: line => ToastService.showError("cardwire Error", line)
        }
        onExited: code => {
            if (code === 0)
                ToastService.showInfo("GPU", "cardwire mode set to " + procCardwireSet.command[2]);
            procCardwireGet.running = true;
        }
    }

    // ---------------- sysfs processes ----------------

    Process {
        id: procPowerUsage
        command: ["sh", Qt.resolvedUrl("get-power-usage.sh").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                root.batteryWattage = trimmed;
                root.hasBattery = trimmed !== "N/A" && trimmed.length > 0;
            }
        }
        onExited: code => {
            if (code === 1)
                root.hasBattery = false;
        }
    }

    Process {
        id: procBatteryStatus
        command: ["sh", Qt.resolvedUrl("get-battery-status.sh").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(/\s+/);
                if (parts.length >= 4) {
                    root.acOnline = parts[0];
                    root.batStatus = parts[1];
                    root.batteryLevel = parseInt(parts[2]) || 0;
                    root.batteryHealthPct = parseInt(parts[3]);
                }
            }
        }
    }

    Process {
        id: procDgpu
        command: ["sh", Qt.resolvedUrl("get-dgpu-state.sh").toString().replace("file://", ""), root.pciAddr]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(/\s+/);
                if (parts.length >= 4) {
                    root.dgpuAddr = parts[0];
                    root.dgpuState = parts[1];
                    root.gpuRuntimeStatus = parts[2];
                    root.gpuPowerControl = parts[3];
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.dgpuState = "...";
        }
    }

    // ---------------- scheduling ----------------

    function refresh() {
        procPowerUsage.running = true;
        procBatteryStatus.running = true;
        procDgpu.running = true;
        if (root.asusCtlAvailable) {
            procPowerGet.running = true;
            procBatteryLimitGet.running = true;
        }
        if (root.cardwireAvailable)
            procCardwireGet.running = true;
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        procAsusCtlInfo.running = true;
        procCardwireInfo.running = true;
        procProfileList.running = true;
        procPowerGet.running = true;
        procBatteryLimitGet.running = true;
        procCardwireGet.running = true;
    }

    // ---------------- actions ----------------

    function setPowerProfile(name) {
        if (name === root.activeProfile || procPowerSet.running)
            return;
        procPowerSet.command = ["asusctl", "profile", "set", name];
        procPowerSet.running = true;
        root.activeProfile = name;
    }

    function setCardwireMode(mode) {
        if (mode === root.cardwireMode || procCardwireSet.running)
            return;
        procCardwireSet.command = ["cardwire", "set", mode];
        procCardwireSet.running = true;
        root.cardwireMode = mode;
    }

    function setBatteryLimit(limit) {
        if (limit < 20 || limit > 100 || procBatteryLimitSet.running)
            return;
        procBatteryLimitSet.command = ["asusctl", "battery", "limit", limit.toString()];
        procBatteryLimitSet.running = true;
        root.batteryLimit = limit;
    }

    function triggerOneShot() {
        if (procBatteryOneShot.running)
            return;
        procBatteryOneShot.running = true;
    }

    // ---------------- presentation helpers ----------------

    function profileIcon(name) {
        if (name === "Performance")
            return "rocket_launch";
        if (name === "Quiet")
            return "bedtime";
        return "balance";
    }

    function capitalize(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    readonly property string batteryLabel: {
        if (!hasBattery)
            return "No battery";
        if (isOnACPower && batStatus === "Full")
            return "Fully charged · Plugged in";
        if (isOnACPower)
            return "Charging · Plugged in";
        if (batStatus === "Discharging")
            return "On battery";
        return batStatus;
    }

    readonly property string batteryIcon: {
        if (!hasBattery)
            return "battery_unknown";
        if (isOnACPower || batStatus === "Charging" || batStatus === "Full")
            return "battery_charging_full";
        return "battery_6_bar";
    }

    readonly property string wattageText: {
        var num = parseFloat(batteryWattage);
        return isNaN(num) ? "N/A" : num.toFixed(1) + " W";
    }

    // ---------------- bar pill ----------------

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: root.profileIcon(root.activeProfile)
                size: Theme.iconSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.wattageText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                visible: root.showWattage && root.hasBattery
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: "│"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                visible: root.showWattage && root.hasBattery && root.showDgpuState && root.dgpuKnown
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.dgpuState
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.dgpuColor
                visible: root.showDgpuState && root.dgpuKnown
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: root.profileIcon(root.activeProfile)
                size: Theme.iconSizeSmall
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.wattageText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                visible: root.showWattage && root.hasBattery
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.dgpuState
                font.pixelSize: Theme.fontSizeSmall
                color: root.dgpuColor
                visible: root.showDgpuState && root.dgpuKnown
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ---------------- popout ----------------

    popoutWidth: 400
    popoutHeight: Math.max(200, contentWrapper.implicitHeight + 60)

    // Section label, GNOME preferences-group style
    component SectionLabel: StyledText {
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceTextMedium
        leftPadding: Theme.spacingS
    }

    // Two-line stat tile
    component StatCard: StyledRect {
        property string label: ""
        property string value: ""
        property color valueColor: Theme.surfaceText
        height: 64
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.width: 0

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            StyledText {
                text: label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: value
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: valueColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Icon + headline + subtitle row heading a section
    component StatusRow: Row {
        property string icon: ""
        property color iconColor: Theme.surfaceText
        property string headline: ""
        property color headlineColor: Theme.primary
        property string tag: ""
        property color tagColor: Theme.surfaceTextMedium
        property string subtitle: ""
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: icon
            size: Theme.iconSizeLarge
            color: iconColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            width: parent.width - Theme.iconSizeLarge - Theme.spacingM
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Row {
                spacing: Theme.spacingS
                StyledText {
                    text: headline
                    font.pixelSize: Theme.fontSizeXLarge
                    font.weight: Font.Bold
                    color: headlineColor
                }
                StyledText {
                    text: tag
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: tagColor
                    visible: tag.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            StyledText {
                width: parent.width
                text: subtitle
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popup
            headerText: "ASUS Control"
            showCloseButton: true

            // Content is re-created each time the popout opens
            Component.onCompleted: {
                procAsusCtlInfo.running = true;
                procCardwireInfo.running = true;
                procProfileList.running = true;
                root.refresh();
            }

            Item {
                id: contentWrapper
                width: parent.width
                implicitHeight: mainCol.implicitHeight

                Column {
                    id: mainCol
                    width: parent.width
                    spacing: Theme.spacingL

                    // Battery
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.hasBattery

                        SectionLabel { text: "Battery" }

                        StatusRow {
                            icon: root.batteryIcon
                            iconColor: root.isOnACPower ? Theme.primary : Theme.surfaceText
                            headline: root.batteryLevel + "%"
                            subtitle: root.batteryLabel
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            StatCard {
                                width: (parent.width - Theme.spacingM) / 2
                                label: "Power"
                                value: root.wattageText
                            }
                            StatCard {
                                width: (parent.width - Theme.spacingM) / 2
                                label: "Health"
                                value: root.batteryHealthPct > 0 ? root.batteryHealthPct + "%" : "N/A"
                                valueColor: root.batteryHealthPct > 0 && root.batteryHealthPct < 80 ? Theme.error : Theme.surfaceText
                            }
                        }
                    }

                    // Power profile
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.asusCtlAvailable

                        SectionLabel { text: "Power Profile" }

                        Row {
                            id: profileRow
                            width: parent.width
                            spacing: Theme.spacingS

                            Repeater {
                                id: profileRepeater
                                model: root.supportedPowerProfiles.length > 0 ? root.supportedPowerProfiles : ["Quiet", "Balanced", "Performance"]

                                StyledRect {
                                    required property string modelData
                                    readonly property bool active: root.activeProfile === modelData
                                    width: (profileRow.width - Theme.spacingS * (profileRepeater.count - 1)) / profileRepeater.count
                                    height: 64
                                    radius: Theme.cornerRadius
                                    color: active ? Theme.primary : Theme.nestedSurface
                                    border.width: 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: root.profileIcon(modelData)
                                            size: 20
                                            color: active ? Theme.primaryText : Theme.surfaceText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        StyledText {
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: active ? Font.Medium : Font.Normal
                                            color: active ? Theme.primaryText : Theme.surfaceText
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setPowerProfile(modelData)
                                    }
                                }
                            }
                        }
                    }

                    // GPU
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.dgpuKnown || root.cardwireAvailable

                        SectionLabel { text: "GPU" }

                        StatusRow {
                            visible: root.dgpuKnown
                            icon: "developer_board"
                            iconColor: root.dgpuColor
                            headline: root.dgpuState
                            headlineColor: root.dgpuIdle ? Theme.primary : root.dgpuColor
                            tag: root.dgpuIdle ? "Idle" : "Active"
                            tagColor: root.dgpuColor
                            subtitle: (root.dgpuIdle ? "Suspended" : "Active, drawing power") + " · " + root.dgpuAddr
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: root.dgpuKnown

                            StatCard {
                                width: (parent.width - Theme.spacingM) / 2
                                label: "Runtime"
                                value: root.gpuRuntimeStatus !== "..." ? root.capitalize(root.gpuRuntimeStatus) : "N/A"
                                valueColor: root.gpuRuntimeStatus === "active" ? root.dgpuColor : Theme.surfaceText
                            }
                            StatCard {
                                width: (parent.width - Theme.spacingM) / 2
                                label: "Power Control"
                                value: root.gpuPowerControl !== "..." ? root.capitalize(root.gpuPowerControl) : "N/A"
                                valueColor: root.gpuPowerControl === "auto" || root.gpuPowerControl === "..." ? Theme.surfaceText : Theme.warning
                            }
                        }

                        Item {
                            width: parent.width
                            height: cwButtons.height * cwButtons.scale
                            visible: root.cardwireAvailable

                            DankButtonGroup {
                                id: cwButtons
                                property var modeModel: root.supportedCardwireModes.length > 0 ? root.supportedCardwireModes.map(root.capitalize) : ["Integrated", "Hybrid"]
                                scale: Math.min(1, parent.width / implicitWidth)
                                transformOrigin: Item.Center
                                anchors.horizontalCenter: parent.horizontalCenter
                                model: modeModel
                                currentIndex: root.supportedCardwireModes.indexOf(root.cardwireMode)
                                selectionMode: "single"
                                buttonHeight: 42
                                minButtonWidth: 80
                                textSize: Theme.fontSizeMedium
                                onSelectionChanged: (index, selected) => {
                                    if (selected)
                                        root.setCardwireMode(root.supportedCardwireModes[index]);
                                }
                            }
                        }
                    }

                    // Charge limit
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.asusCtlAvailable && root.hasBattery

                        SectionLabel { text: "Charge Limit" }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankSlider {
                                width: parent.width - 48 - 44 - Theme.spacingS * 2
                                value: root.batteryLimit
                                minimum: 20
                                maximum: 100
                                step: 5
                                unit: "%"
                                leftIcon: "battery_std"
                                rightIcon: "battery_charging_full"
                                anchors.verticalCenter: parent.verticalCenter
                                onSliderDragFinished: finalValue => root.setBatteryLimit(finalValue)
                            }
                            StyledText {
                                width: 44
                                text: root.batteryLimit + "%"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // One-shot: charge to 100% once, then the limit resumes
                            StyledRect {
                                width: 48
                                height: 36
                                radius: Theme.cornerRadius
                                color: oneShotArea.containsMouse ? Theme.surfaceContainerHigh : Theme.nestedSurface
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: "bolt"
                                    size: 20
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                                MouseArea {
                                    id: oneShotArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.triggerOneShot()
                                }
                            }
                        }
                    }

                    // Footer
                    StyledText {
                        width: parent.width
                        text: "asusctl " + (root.asusCtlInfo || "…") + "   ·   cardwire " + (root.cardwireInfo || "…")
                        font.pixelSize: Theme.fontSizeSmall
                        color: (root.asusCtlInfo === "MISSING" || root.cardwireInfo === "MISSING") ? Theme.error : Theme.surfaceTextMedium
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
