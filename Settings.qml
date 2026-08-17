import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "scratchpadHelper"

    readonly property bool showStatusWarning: !CompositorService.isMango || !MangoService.available
    property bool showNamedInfo: false
    property bool showNamedDiagnostics: false

    readonly property string namedDiagnosticText: String(namedConfig.errorText || namedConfig.targetScanError || namedConfig.mainScanError).trim()
    readonly property bool namedHasDiagnostics: namedDiagnosticText.length > 0
    readonly property bool namedHasError: namedConfig.ownership === "conflict" || namedConfig.errorText.length > 0 || namedConfig.targetScanError.length > 0 || namedConfig.mainScanError.length > 0
    readonly property bool namedNeedsSetup: namedConfig.managerEnabled && (!namedConfig.includeConfigured || !namedConfig.targetExists)
    readonly property string namedStatusIcon: namedConfig.ownership === "conflict" ? "warning" : (root.namedHasError ? "error" : (root.namedNeedsSetup ? "info" : (namedConfig.targetScanned && namedConfig.mainScanned ? "check_circle" : "sync")))
    readonly property color namedStatusColor: namedConfig.ownership === "conflict" || root.namedNeedsSetup ? Theme.warning : (root.namedHasError ? Theme.error : (namedConfig.targetScanned && namedConfig.mainScanned ? Theme.primary : Theme.surfaceVariantText))

    NamedScratchpadConfig {
        id: namedConfig
    }

    onNamedDiagnosticTextChanged: {
        if (!namedHasDiagnostics)
            showNamedDiagnostics = false;
    }

    StyledText {
        width: parent.width
        text: !CompositorService.isMango ? "Unsupported compositor" : "Mango unavailable"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        visible: root.showStatusWarning
    }

    StyledRect {
        width: parent.width
        height: statusColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        visible: root.showStatusWarning

        Column {
            id: statusColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM

            StyledText {
                width: parent.width
                text: !CompositorService.isMango ? "Scratchpad Helper currently supports MangoWM." : "Scratchpad Helper can't access Mango window state."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Appearance"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
    }

    StyledRect {
        width: parent.width
        height: appearanceColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: appearanceColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            ToggleSetting {
                settingKey: "showApplicationIcons"
                label: "Show application icons"
                description: "Use the matching desktop application's icon in each card"
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "hideBarWhenEmpty"
                label: "Hide bar indicator when empty"
                description: "Collapse the DankBar widget when Mango reports no scratchpad windows"
                defaultValue: false
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Cached previews"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        topPadding: Theme.spacingM
    }

    StyledRect {
        width: parent.width
        height: previewsColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: previewsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            ToggleSetting {
                settingKey: "cachedPreviews"
                label: "Capture cached previews"
                description: "Capture once before a helper stash. Disabling this keeps existing cache files and uses the normal card fallback for new stashes."
                defaultValue: true
            }

            StyledText {
                width: parent.width
                text: {
                    if (!CompositorService.isMango)
                        return "Preview capture is inactive outside MangoWM.";
                    const known = PluginService.getGlobalVar("scratchpadHelper", "grimStatusKnown", false);
                    if (!known)
                        return "grim availability is checked on the first helper stash.";
                    const available = PluginService.getGlobalVar("scratchpadHelper", "grimAvailable", false);
                    return available ? "grim is available for window capture." : "grim is unavailable. Stash still works without thumbnails.";
                }
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    Item {
        width: parent.width
        height: namedHeading.implicitHeight + Theme.spacingM

        StyledText {
            id: namedHeading
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: "Named scratchpads"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
        }

        DankActionButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -Theme.spacingXS
            iconName: "info"
            iconColor: root.showNamedInfo ? Theme.primary : Theme.surfaceVariantText
            buttonSize: Theme.iconSize + Theme.spacingS
            onClicked: root.showNamedInfo = !root.showNamedInfo
        }
    }

    StyledRect {
        width: parent.width
        height: namedInfoColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        visible: root.showNamedInfo

        Column {
            id: namedInfoColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: "About named scratchpads"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }

            StyledText {
                width: parent.width
                text: "Scratchpad Helper manages named scratchpads you create here. Existing Mango named scratchpads are left alone.\n\nIt stores its rules in ~/.config/mango/scratchpad-helper.conf. Add the include line to your Mango config once; Scratchpad Helper never edits your main Mango config automatically. Turning the manager off keeps the generated file. Reload Mango applies configuration changes."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    StyledRect {
        width: parent.width
        height: namedColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: namedColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                width: parent.width
                text: "Manage named scratchpads with Scratchpad Helper."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            ToggleSetting {
                settingKey: "namedManagerEnabled"
                label: "Enable Named Scratchpad Manager"
                description: ""
                defaultValue: false
            }

            StyledRect {
                width: parent.width
                height: namedStatusRow.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(root.namedStatusColor, 0.1)
                border.color: Theme.withAlpha(root.namedStatusColor, 0.5)
                border.width: Theme.layerOutlineWidth
                visible: namedConfig.managerEnabled

                Row {
                    id: namedStatusRow
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        anchors.top: parent.top
                        name: root.namedStatusIcon
                        size: Theme.iconSize
                        color: root.namedStatusColor
                    }

                    Column {
                        width: parent.width - Theme.iconSize - parent.spacing
                        spacing: Theme.spacingXXS

                        StyledText {
                            width: parent.width
                            text: namedConfig.status
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            width: parent.width
                            visible: namedConfig.detail.length > 0
                            text: namedConfig.detail
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: includeColumn.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                visible: namedConfig.managerEnabled && !namedConfig.includeConfigured

                Column {
                    id: includeColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: "Add this line to your Mango config:"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                    }

                    StyledText {
                        width: parent.width
                        text: namedConfig.includeLine
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.monoFontFamily
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                visible: namedConfig.managerEnabled

                DankButton {
                    text: "Copy"
                    visible: !namedConfig.includeConfigured
                    enabled: !namedConfig.busy
                    onClicked: namedConfig.copyIncludeLine()
                }

                DankButton {
                    text: namedConfig.busy ? "Working…" : "Generate config"
                    enabled: !namedConfig.busy && namedConfig.ownership !== "conflict"
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: namedConfig.generate()
                }

                DankButton {
                    text: "Reload Mango"
                    visible: namedConfig.reloadNeeded
                    enabled: !namedConfig.busy && namedConfig.generatedValid && namedConfig.includeConfigured
                    onClicked: namedConfig.reloadMango()
                }

                DankButton {
                    text: root.showNamedDiagnostics ? "Hide details" : "Details"
                    visible: root.namedHasDiagnostics
                    enabled: !namedConfig.busy
                    onClicked: root.showNamedDiagnostics = !root.showNamedDiagnostics
                }
            }

            StyledRect {
                width: parent.width
                height: diagnosticText.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                visible: namedConfig.managerEnabled && root.showNamedDiagnostics && root.namedHasDiagnostics

                StyledText {
                    id: diagnosticText
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    text: root.namedDiagnosticText
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
