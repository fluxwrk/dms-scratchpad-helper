pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "ScratchpadNavigation.js" as ScratchpadNavigation

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

    function requestClientActivation(clientId) {
        const request = {
            "clientId": clientId,
            "token": Date.now()
        };
        PluginService.setGlobalVar(scratchpadPluginId, "activateRequest", request);
        closePopout();
    }

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
        Column {
            id: popout
            property var closePopout: null
            property var parentPopout: null
            property var keyboardParentPopout: null
            property string selectedClientId: ""
            property int selectedVisualIndex: -1
            readonly property int headerHeight: 40
            readonly property int navigationColumns: width >= 360 ? 2 : 1
            spacing: 0
            focus: true

            function resetSelection() {
                selectedClientId = ScratchpadNavigation.firstActionableId(root.scratchpadClients);
                selectedVisualIndex = ScratchpadNavigation.indexOfClient(root.scratchpadClients, selectedClientId);
                Qt.callLater(() => picker.revealClient(selectedClientId));
            }

            function reconcileSelection() {
                const selection = ScratchpadNavigation.reconcileSelection(root.scratchpadClients, selectedClientId, selectedVisualIndex);
                selectedClientId = selection.clientId;
                selectedVisualIndex = selection.index;
                Qt.callLater(() => picker.revealClient(selectedClientId));
            }

            function moveSelection(direction) {
                selectedClientId = ScratchpadNavigation.moveSelection(root.scratchpadClients, selectedClientId, direction, navigationColumns);
                selectedVisualIndex = ScratchpadNavigation.indexOfClient(root.scratchpadClients, selectedClientId);
                Qt.callLater(() => picker.revealClient(selectedClientId));
            }

            function takeKeyboardFocus() {
                resetSelection();
                Qt.callLater(() => popout.forceActiveFocus());
            }

            onParentPopoutChanged: {
                if (keyboardParentPopout && keyboardParentPopout !== parentPopout)
                    keyboardParentPopout.contentHandlesKeys = false;
                keyboardParentPopout = parentPopout;
                if (keyboardParentPopout)
                    keyboardParentPopout.contentHandlesKeys = true;
                if (parentPopout?.shouldBeVisible)
                    takeKeyboardFocus();
            }

            Component.onDestruction: {
                if (keyboardParentPopout)
                    keyboardParentPopout.contentHandlesKeys = false;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left)
                    moveSelection("left");
                else if (event.key === Qt.Key_Right)
                    moveSelection("right");
                else if (event.key === Qt.Key_Up)
                    moveSelection("up");
                else if (event.key === Qt.Key_Down)
                    moveSelection("down");
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (selectedClientId !== "")
                        picker.activateRequested(selectedClientId);
                } else if (event.key === Qt.Key_Escape) {
                    if (closePopout)
                        closePopout();
                } else {
                    return;
                }
                event.accepted = true;
            }

            Connections {
                target: popout.parentPopout

                function onOpened() {
                    popout.takeKeyboardFocus();
                }
            }

            Connections {
                target: root

                function onScratchpadClientsChanged() {
                    popout.reconcileSelection();
                }
            }

            Item {
                width: parent.width
                height: popout.headerHeight

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Scratchpad"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: 32
                    height: 32
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 16
                    color: closeArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.iconSize - 4
                        color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            if (popout.closePopout)
                                popout.closePopout();
                        }
                    }
                }
            }

            ScratchpadPicker {
                id: picker
                width: parent.width
                height: root.popoutHeight - popout.headerHeight - Theme.spacingL
                clients: root.scratchpadClients
                isMango: root.isMango
                serviceAvailable: root.serviceAvailable
                showApplicationIcons: root.showApplicationIcons
                selectedClientId: popout.selectedClientId
                onActivateRequested: clientId => root.requestClientActivation(clientId)
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
            onActivateRequested: clientId => root.requestClientActivation(clientId)
        }
    }
}
