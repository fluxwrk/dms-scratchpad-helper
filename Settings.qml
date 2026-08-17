import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "scratchpadHelper"

    readonly property bool showStatusWarning: !CompositorService.isMango || !MangoService.available

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

    StyledText {
        width: parent.width
        text: "Named scratchpads"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        topPadding: Theme.spacingM
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

            StyledText {
                width: parent.width
                text: "Detected named scratchpads are currently shown as informational cards. Management is planned for a future build."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
