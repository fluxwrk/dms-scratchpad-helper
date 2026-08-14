import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property var clients: []
    property bool isMango: false
    property bool serviceAvailable: false
    property bool showApplicationIcons: true

    readonly property string stateText: !isMango ? "Scratchpad Helper requires MangoWM." : (!serviceAvailable ? "Mango service is unavailable." : "Scratchpad is empty")
    readonly property string stateIcon: !isMango ? "desktop_access_disabled" : (!serviceAvailable ? "link_off" : "select_window")

    Item {
        anchors.fill: parent
        visible: root.clients.length === 0

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.stateIcon
                size: Theme.iconSizeLarge
                color: Theme.onSurfaceVariant
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.stateText
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        visible: root.clients.length > 0
        contentHeight: cardFlow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: cardFlow
            width: parent.width
            spacing: Theme.spacingM

            Repeater {
                model: root.clients

                ScratchpadCard {
                    required property var modelData
                    width: cardFlow.width >= 360 ? (cardFlow.width - cardFlow.spacing) / 2 : cardFlow.width
                    client: modelData
                    showApplicationIcon: root.showApplicationIcons
                }
            }
        }
    }
}
