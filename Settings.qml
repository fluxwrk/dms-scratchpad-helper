import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "scratchpadHelper"

    StyledText {
        width: parent.width
        text: "General"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    StyledText {
        width: parent.width
        text: !CompositorService.isMango ? "Scratchpad Helper requires MangoWM." : (!MangoService.available ? "DMS is not connected to Mango's IPC socket." : "Using DMS MangoService for scratchpad state.")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

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

    StyledText {
        width: parent.width
        text: "Cached previews"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        topPadding: Theme.spacingM
    }

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

    StyledText {
        width: parent.width
        text: "Named Scratchpad Manager"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        topPadding: Theme.spacingM
    }

    StyledText {
        width: parent.width
        text: "Coming in a future build. Existing named scratchpads are already detected and displayed."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
