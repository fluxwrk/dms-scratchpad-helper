import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property var client
    property bool showApplicationIcon: true
    signal activated(var clientId)

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

            StyledRect {
                id: previewFrame
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHighest
                clip: true

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: root.client.previewUrl || ""
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    visible: root.client.hasPreview === true && status === Image.Ready
                }
            }

            ScratchpadAppIcon {
                id: appIcon
                anchors.centerIn: parent
                width: Theme.iconSizeLarge * 1.5
                height: width
                appId: root.client.appId
                visible: previewImage.status !== Image.Ready && root.showApplicationIcon
            }

            DankIcon {
                anchors.centerIn: parent
                name: "select_window"
                size: Theme.iconSizeLarge
                color: Theme.onSurfaceVariant
                visible: previewImage.status !== Image.Ready && !root.showApplicationIcon
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

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        enabled: root.client.type === "standard"
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated(root.client.clientId)
    }
}
