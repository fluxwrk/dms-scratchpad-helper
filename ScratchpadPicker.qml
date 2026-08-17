import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var clients: []
    property bool isMango: false
    property bool serviceAvailable: false
    property bool showApplicationIcons: true
    property var selectedClientId: ""
    signal activateRequested(var clientId)

    readonly property string stateTitle: !isMango ? "MangoWM required" : (!serviceAvailable ? "Mango service unavailable" : "No scratchpad windows")
    readonly property string stateText: !isMango ? "Scratchpad Helper currently supports MangoWM." : (!serviceAvailable ? "DMS is not connected to Mango's IPC socket." : "Stashed windows will appear here.")
    readonly property string stateIcon: !isMango ? "desktop_access_disabled" : (!serviceAvailable ? "link_off" : "select_window")

    function revealClient(clientId) {
        const selected = String(clientId ?? "");
        if (!selected || !flickable.visible)
            return;
        for (let i = 0; i < clients.length; ++i) {
            if (String(clients[i]?.clientId ?? "") !== selected)
                continue;
            const card = cardRepeater.itemAt(i);
            if (!card)
                return;
            const top = card.y;
            const bottom = top + card.height;
            if (top < flickable.contentY)
                flickable.contentY = Math.max(0, top);
            else if (bottom > flickable.contentY + flickable.height)
                flickable.contentY = Math.min(Math.max(0, flickable.contentHeight - flickable.height), bottom - flickable.height);
            return;
        }
    }

    Item {
        anchors.fill: parent
        visible: root.clients.length === 0

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            width: Math.min(parent.width - Theme.spacingXL * 2, 300)

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.stateIcon
                size: Theme.iconSizeLarge
                color: Theme.onSurfaceVariant
            }

            StyledText {
                width: parent.width
                text: root.stateTitle
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: root.stateText
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    DankFlickable {
        id: flickable
        anchors.fill: parent
        visible: root.clients.length > 0
        contentHeight: cardFlow.implicitHeight + Theme.spacingS
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: cardFlow
            x: Theme.spacingS
            y: Theme.spacingXS
            width: parent.width - Theme.spacingL
            spacing: Theme.spacingS

            Repeater {
                id: cardRepeater
                model: root.clients

                ScratchpadCard {
                    required property var modelData
                    width: cardFlow.width >= 360 ? (cardFlow.width - cardFlow.spacing) / 2 : cardFlow.width
                    client: modelData
                    showApplicationIcon: root.showApplicationIcons
                    selected: root.selectedClientId !== "" && String(root.selectedClientId) === String(modelData.clientId)
                    onActivated: clientId => root.activateRequested(clientId)
                }
            }
        }
    }
}
