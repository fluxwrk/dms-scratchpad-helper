import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property var client
    property bool showApplicationIcon: true

    height: 142
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.width: client.type === "named" ? 1 : 0
    border.color: Theme.primary

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: 70

            ScratchpadAppIcon {
                id: appIcon
                anchors.centerIn: parent
                width: Theme.iconSizeLarge * 1.5
                height: width
                appId: root.client.appId
                visible: root.showApplicationIcon
            }

            DankIcon {
                anchors.centerIn: parent
                name: "select_window"
                size: Theme.iconSizeLarge
                color: Theme.onSurfaceVariant
                visible: !root.showApplicationIcon
            }

            StyledRect {
                anchors.top: parent.top
                anchors.right: parent.right
                visible: root.client.type === "named"
                width: namedText.implicitWidth + Theme.spacingS * 2
                height: namedText.implicitHeight + Theme.spacingXS * 2
                radius: Theme.cornerRadius
                color: Theme.primaryContainer

                StyledText {
                    id: namedText
                    anchors.centerIn: parent
                    text: "Named"
                    color: Theme.onPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }

        StyledText {
            width: parent.width
            text: appIcon.appName
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            text: root.client.title || "Untitled"
            color: Theme.surfaceTextSecondary
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
