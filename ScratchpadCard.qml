import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property var client
    property bool showApplicationIcon: true
    property bool selected: false
    signal activated(var clientId)

    readonly property bool actionable: client.type === "standard"
    readonly property bool hovered: actionable && cardMouseArea.containsMouse

    height: 148
    radius: Theme.cornerRadius
    color: selected ? Theme.primaryPressed : (hovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency))
    border.width: selected ? 2 : (client.type === "named" ? Theme.layerOutlineWidth : 0)
    border.color: selected ? Theme.primary : Theme.outlineMedium

    DankRipple {
        id: rippleLayer
        rippleColor: Theme.surfaceText
        cornerRadius: root.radius
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: 90

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
                id: previewAppIcon
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
                radius: height / 2
                color: Theme.secondaryContainer

                StyledText {
                    id: namedText
                    anchors.centerIn: parent
                    text: "Named"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }

        Row {
            width: parent.width
            height: 34
            spacing: Theme.spacingS

            ScratchpadAppIcon {
                id: metadataAppIcon
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.iconSize + Theme.spacingXS
                height: width
                appId: root.client.appId
                visible: root.showApplicationIcon
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (metadataAppIcon.visible ? metadataAppIcon.width + parent.spacing : 0)
                spacing: Theme.spacingXXS

                StyledText {
                    width: parent.width
                    text: metadataAppIcon.appName
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: root.client.title || "Untitled"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        enabled: root.actionable
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => rippleLayer.trigger(mouse.x, mouse.y)
        onClicked: root.activated(root.client.clientId)
    }
}
