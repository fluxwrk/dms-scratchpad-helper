import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: root

    property string appId: ""
    property var desktopEntry: null
    readonly property string appName: {
        const fallback = appId || "Unknown application";
        const resolved = Paths.getAppName(appId, desktopEntry);
        return resolved && String(resolved).trim().length > 0 ? String(resolved) : fallback;
    }

    function resolveDesktopEntry() {
        if (!appId) {
            desktopEntry = null;
            return;
        }
        desktopEntry = DesktopEntries.heuristicLookup(Paths.moddedAppId(appId));
    }

    Component.onCompleted: resolveDesktopEntry()
    onAppIdChanged: resolveDesktopEntry()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.resolveDesktopEntry();
        }
    }

    IconImage {
        id: iconImage
        anchors.fill: parent
        source: Paths.getAppIcon(root.appId, root.desktopEntry)
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    DankIcon {
        anchors.centerIn: parent
        name: "apps"
        size: Math.min(root.width, root.height)
        color: Theme.onSurfaceVariant
        visible: iconImage.status !== Image.Ready
    }
}
