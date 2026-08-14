import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "ScratchpadModel.js" as ScratchpadModel

PluginComponent {
    id: root

    readonly property var log: Log.scoped("ScratchpadHelper")
    property var popoutService: null
    property int lastPublishedCount: -1

    function rebuildModel() {
        const isMango = CompositorService.isMango === true;
        const serviceAvailable = isMango && MangoService.available === true;
        const source = serviceAvailable && Array.isArray(MangoService.windows) ? MangoService.windows : [];
        const scratchpads = ScratchpadModel.normalizeClients(source);

        pluginService?.setGlobalVar(pluginId, "isMango", isMango);
        pluginService?.setGlobalVar(pluginId, "serviceAvailable", serviceAvailable);
        pluginService?.setGlobalVar(pluginId, "clients", scratchpads);

        if (scratchpads.length !== lastPublishedCount) {
            log.info("Published", scratchpads.length, "scratchpad client(s)");
            lastPublishedCount = scratchpads.length;
        }
    }

    Connections {
        target: MangoService

        function onWindowsChanged() {
            root.rebuildModel();
        }

        function onAvailableChanged() {
            root.rebuildModel();
        }
    }

    Connections {
        target: CompositorService

        function onIsMangoChanged() {
            root.rebuildModel();
        }
    }

    IpcHandler {
        target: "scratchpadHelper"

        function togglePicker(): string {
            if (!CompositorService.isMango)
                return "UNSUPPORTED: Scratchpad Helper requires MangoWM";
            if (!MangoService.available)
                return "UNAVAILABLE: DMS MangoService is not connected";

            const token = pluginService?.getGlobalVar(root.pluginId, "pickerRequest", 0) ?? 0;
            pluginService?.setGlobalVar(root.pluginId, "pickerRequest", token + 1);
            return "TOGGLE_REQUESTED: requires a Scratchpad Helper DankBar widget on the focused screen";
        }

        function status(): string {
            if (!CompositorService.isMango)
                return "unsupported\t0";
            if (!MangoService.available)
                return "unavailable\t0";
            const clients = pluginService?.getGlobalVar(root.pluginId, "clients", []) ?? [];
            return "active\t" + clients.length;
        }
    }

    Component.onCompleted: {
        log.info("Started; using DMS MangoService.windows");
        rebuildModel();
    }

    Component.onDestruction: log.info("Stopped")
}
