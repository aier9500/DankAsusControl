import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankAsusControlCenter"

    StyledText {
        width: parent.width
        text: "Bar"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceVariantText
    }

    ToggleSetting {
        settingKey: "showWattage"
        label: "Show battery wattage"
        description: "Current power draw next to the profile icon"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showDgpuState"
        label: "Show dGPU power state"
        description: "D0 (active) or D3cold (suspended) next to the wattage"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh interval"
        description: "How often battery, GPU and profile data are polled"
        defaultValue: 5
        minimum: 1
        maximum: 30
        unit: "s"
        leftIcon: "schedule"
    }

    StyledText {
        width: parent.width
        text: "dGPU"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceVariantText
    }

    StringSetting {
        settingKey: "pciAddress"
        label: "PCI address"
        description: "Leave empty to auto-detect. Find it with: lspci | grep -iE 'vga|3d'"
        placeholder: "auto"
        defaultValue: ""
    }
}
