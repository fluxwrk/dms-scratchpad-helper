pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string scratchpadPluginId: "scratchpadHelper"
    layerNamespacePlugin: "scratchpad-helper"
    property var popoutService: null

    // DetailHost creates a fresh component without plugin host injection, so all
    // shared reads use the manifest ID rather than the injected pluginId.
    readonly property var scratchpadClients: PluginService.getGlobalVar(scratchpadPluginId, "clients", [])
    readonly property bool isMango: PluginService.getGlobalVar(scratchpadPluginId, "isMango", CompositorService.isMango)
    readonly property bool serviceAvailable: PluginService.getGlobalVar(scratchpadPluginId, "serviceAvailable", false)
    readonly property bool showApplicationIcons: SettingsData.getPluginSetting(scratchpadPluginId, "showApplicationIcons", true)
    readonly property bool hideBarWhenEmpty: SettingsData.getPluginSetting(scratchpadPluginId, "hideBarWhenEmpty", false)
    readonly property int scratchpadCount: scratchpadClients.length

    function isFocusedScreenWidget() {
        if (!root.parentScreen || !root.axis)
            return false;
        const focused = CompositorService.getFocusedScreen();
        return focused && focused.name === root.parentScreen.name;
    }

    Connections {
        target: PluginService

        function onGlobalVarChanged(changedPluginId, varName) {
            if (changedPluginId === root.scratchpadPluginId && varName === "pickerRequest" && root.isFocusedScreenWidget())
                root.triggerPopout();
        }
    }

    Component.onCompleted: setVisibilityOverride(!(hideBarWhenEmpty && scratchpadCount === 0))
    onHideBarWhenEmptyChanged: setVisibilityOverride(!(hideBarWhenEmpty && scratchpadCount === 0))
    onScratchpadCountChanged: setVisibilityOverride(!(hideBarWhenEmpty && scratchpadCount === 0))

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "select_window"
                size: root.iconSize
                color: root.isMango && root.serviceAvailable ? Theme.surfaceText : Theme.onSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.scratchpadCount
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "select_window"
                size: root.iconSize
                color: root.isMango && root.serviceAvailable ? Theme.surfaceText : Theme.onSurfaceVariant
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.scratchpadCount
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
            }
        }
    }

    popoutWidth: 440
    popoutHeight: 360

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Scratchpad"
            showCloseButton: true

            ScratchpadPicker {
                width: parent.width
                height: root.popoutHeight - popout.headerHeight - Theme.spacingL
                clients: root.scratchpadClients
                isMango: root.isMango
                serviceAvailable: root.serviceAvailable
                showApplicationIcons: root.showApplicationIcons
            }
        }
    }

    ccWidgetIcon: "select_window"
    ccWidgetPrimaryText: "Scratchpad"
    ccWidgetSecondaryText: !isMango ? "Requires MangoWM" : (serviceAvailable ? scratchpadCount + (scratchpadCount === 1 ? " window" : " windows") : "Mango service unavailable")
    ccWidgetIsActive: isMango && serviceAvailable && scratchpadCount > 0

    ccDetailHeight: 320
    ccDetailContent: Component {
        ScratchpadPicker {
            implicitHeight: 300
            clients: root.scratchpadClients
            isMango: root.isMango
            serviceAvailable: root.serviceAvailable
            showApplicationIcons: root.showApplicationIcons
        }
    }
}
