import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "PreviewCache.js" as PreviewCache
import "ScratchpadModel.js" as ScratchpadModel
import "NamedScratchpadDefinitions.js" as NamedDefinitions
import "NamedScratchpadRuntime.js" as NamedRuntime
import "StashWorkflow.js" as StashWorkflow
import "MangoConfigPaths.js" as MangoConfigPaths

PluginComponent {
    id: root

    readonly property var log: Log.scoped("ScratchpadHelper")
    readonly property string cacheRoot: Paths.strip(Paths.xdgCache) + "/scratchpad-helper/previews"
    readonly property string mangoInstanceIdentity: MangoService.socketPath
    readonly property string instanceDirectoryName: PreviewCache.instanceDirectoryName(mangoInstanceIdentity)
    readonly property string cacheDir: PreviewCache.instanceCacheDir(cacheRoot, mangoInstanceIdentity)
    readonly property int previewWidth: 320
    property var popoutService: null
    property int lastPublishedCount: -1
    property bool stashBusy: false
    property bool grimAvailable: false
    property bool grimStatusKnown: false
    property bool mmsgAvailable: false
    property var previewEntries: ({})
    property var suppressedPreviewIds: ({})
    property string namedConfigContent: ""
    property bool namedConfigReadable: false

    readonly property string homePath: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    readonly property url namedConfigUrl: Paths.toFileUrl(MangoConfigPaths.helperConfigPath(homePath))
    readonly property var namedPluginSettings: SettingsData.getPluginSettingsForPlugin(pluginId)
    readonly property var namedDefinitionStore: namedPluginSettings.namedManagerStore === undefined ? null : namedPluginSettings.namedManagerStore
    readonly property bool namedManagerEnabled: SettingsData.getPluginSetting(pluginId, "namedManagerEnabled", false)
    readonly property string namedGeneratedHash: SettingsData.getPluginSetting(pluginId, "namedManagerGeneratedHash", "")
    readonly property string namedAppliedHash: SettingsData.getPluginSetting(pluginId, "namedManagerAppliedHash", "")
    readonly property bool namedConfigSynchronized: {
        if (!namedConfigReadable || !namedGeneratedHash || namedAppliedHash !== namedGeneratedHash)
            return false;
        const state = NamedDefinitions.generatedContentState(namedDefinitionStore, namedConfigContent, namedGeneratedHash);
        return state.state === "current";
    }

    readonly property bool previewsEnabled: SettingsData.getPluginSetting("scratchpadHelper", "cachedPreviews", true)

    function publishStatus() {
        pluginService?.setGlobalVar(pluginId, "grimAvailable", grimAvailable);
        pluginService?.setGlobalVar(pluginId, "grimStatusKnown", grimStatusKnown);
        pluginService?.setGlobalVar(pluginId, "mmsgAvailable", mmsgAvailable);
        pluginService?.setGlobalVar(pluginId, "previewsEnabled", previewsEnabled);
        pluginService?.setGlobalVar(pluginId, "stashBusy", stashBusy);
    }

    function rebuildModel() {
        const isMango = CompositorService.isMango === true;
        const serviceAvailable = isMango && MangoService.available === true;
        const source = serviceAvailable && Array.isArray(MangoService.windows) ? MangoService.windows : [];
        const namedAssociations = NamedRuntime.classify(source, namedDefinitionStore,
            namedManagerEnabled, namedConfigSynchronized, NamedDefinitions);
        const scratchpads = ScratchpadModel.normalizeClients(source, previewEntries, namedAssociations);

        pluginService?.setGlobalVar(pluginId, "isMango", isMango);
        pluginService?.setGlobalVar(pluginId, "serviceAvailable", serviceAvailable);
        pluginService?.setGlobalVar(pluginId, "clients", scratchpads);
        publishStatus();

        if (scratchpads.length !== lastPublishedCount) {
            log.info("Published", scratchpads.length, "scratchpad client(s)");
            lastPublishedCount = scratchpads.length;
        }
    }

    function setupCache() {
        if (!cacheDir) {
            log.info("Preview cache is inactive without a Mango instance identity");
            return;
        }
        Proc.runCommand(null, ["mkdir", "-p", cacheDir], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Could not create preview cache:", output || "mkdir failed");
                return;
            }
            cacheRootFolder.folder = Paths.toFileUrl(cacheRoot);
            previewFolder.folder = Paths.toFileUrl(cacheDir);
        }, 0, 5000);
    }

    function reconcileInstanceDirectories() {
        if (cacheRootFolder.status !== FolderListModel.Ready || !instanceDirectoryName)
            return;
        for (let i = 0; i < cacheRootFolder.count; ++i) {
            const fileName = cacheRootFolder.get(i, "fileName");
            const isDirectory = cacheRootFolder.isFolder(i);
            if (isDirectory && PreviewCache.isInstanceDirectoryName(fileName) && !PreviewCache.isCurrentInstanceDirectory(fileName, mangoInstanceIdentity)) {
                const path = cacheRoot + "/" + fileName;
                Proc.runCommand(null, ["rm", "-rf", "--", path], (output, exitCode) => {
                    if (exitCode !== 0)
                        log.warn("Could not remove old Mango-session preview cache", fileName, output || "rm failed");
                }, 0, 5000);
            } else if (!isDirectory && (PreviewCache.clientIdFromFileName(fileName) || PreviewCache.isTemporaryFileName(fileName))) {
                const path = cacheRoot + "/" + fileName;
                Proc.runCommand(null, ["rm", "-f", path], (output, exitCode) => {
                    if (exitCode !== 0)
                        log.warn("Could not remove legacy preview cache file", fileName, output || "rm failed");
                }, 0, 5000);
            }
        }
    }

    function ensureGrimAvailable(done) {
        if (grimStatusKnown) {
            done(grimAvailable);
            return;
        }
        Proc.runCommand(null, ["grim", "-h"], (output, exitCode) => {
            grimAvailable = exitCode === 0;
            grimStatusKnown = true;
            if (!grimAvailable)
                log.info("grim is unavailable; cached previews will use the icon fallback");
            publishStatus();
            done(grimAvailable);
        }, 0, 3000);
    }

    function refreshPreviewEntries() {
        if (previewFolder.status !== FolderListModel.Ready)
            return;
        const entries = {};
        for (let i = 0; i < previewFolder.count; ++i) {
            const fileName = previewFolder.get(i, "fileName");
            const id = PreviewCache.clientIdFromFileName(fileName);
            if (!id || suppressedPreviewIds[id])
                continue;
            const path = PreviewCache.filePathForClient(cacheDir, id);
            const modified = previewFolder.get(i, "fileModified");
            const revision = modified?.getTime ? modified.getTime() : 0;
            entries[id] = {
                "path": path,
                "url": Paths.toFileUrl(path) + "?v=" + revision
            };
        }
        previewEntries = entries;
        rebuildModel();
        reconcileCache();
    }

    function reconcileCache() {
        if (previewFolder.status !== FolderListModel.Ready || !CompositorService.isMango || !MangoService.available || !Array.isArray(MangoService.windows))
            return;
        const activeIds = PreviewCache.activeClientIds(MangoService.windows);
        const suppressed = {};
        for (const id of Object.keys(suppressedPreviewIds)) {
            if (activeIds[id])
                suppressed[id] = true;
        }
        suppressedPreviewIds = suppressed;
        for (let i = 0; i < previewFolder.count; ++i) {
            const fileName = previewFolder.get(i, "fileName");
            const id = PreviewCache.clientIdFromFileName(fileName);
            if ((PreviewCache.isTemporaryFileName(fileName) && !stashBusy) || (id && !activeIds[id]))
                removeOwnedCacheFile(fileName);
        }
    }

    function removeOwnedCacheFile(fileName) {
        const id = PreviewCache.clientIdFromFileName(fileName);
        if (!id && !PreviewCache.isTemporaryFileName(fileName))
            return;
        const path = cacheDir + "/" + fileName;
        Proc.runCommand(null, ["rm", "-f", path], (output, exitCode) => {
            if (exitCode !== 0)
                log.warn("Could not remove stale preview", fileName, output || "rm failed");
        }, 0, 5000);
    }

    function recordPreview(clientId, path) {
        const id = PreviewCache.normalizeClientId(clientId);
        if (!id)
            return;
        const suppressed = Object.assign({}, suppressedPreviewIds);
        delete suppressed[id];
        suppressedPreviewIds = suppressed;
        const entries = Object.assign({}, previewEntries);
        entries[id] = {
            "path": path,
            "url": Paths.toFileUrl(path) + "?v=" + Date.now()
        };
        previewEntries = entries;
        rebuildModel();
    }

    function discardPreview(clientId) {
        const id = PreviewCache.normalizeClientId(clientId);
        if (!id)
            return;
        const suppressed = Object.assign({}, suppressedPreviewIds);
        suppressed[id] = true;
        suppressedPreviewIds = suppressed;
        previewEntries = PreviewCache.withoutClientPreview(previewEntries, id);
        rebuildModel();
        removeOwnedCacheFile(PreviewCache.fileNameForClient(id));
    }

    function queryFocusedClient(callback) {
        Proc.runCommand(null, ["mmsg", "get", "focusing-client"], (output, exitCode) => {
            mmsgAvailable = exitCode === 0;
            publishStatus();
            callback(exitCode === 0 ? StashWorkflow.parseFocusedClient(output) : null, output);
        }, 0, 5000);
    }

    function capturePreview(client, done) {
        if (!previewsEnabled || !StashWorkflow.validCaptureGeometry(client)) {
            done(false, "", "");
            return;
        }

        ensureGrimAvailable(available => {
            if (!PreviewCache.captureAllowed(previewsEnabled, available, true)) {
                done(false, "", "");
                return;
            }

            Proc.runCommand(null, ["mkdir", "-p", cacheDir], (mkdirOutput, mkdirExitCode) => {
                if (mkdirExitCode !== 0) {
                    log.warn("Preview capture skipped; cache directory is unavailable");
                    done(false, "", "");
                    return;
                }
                const id = PreviewCache.normalizeClientId(client.id);
                const finalPath = PreviewCache.filePathForClient(cacheDir, id);
                const temporaryName = PreviewCache.temporaryFileNameForClient(id);
                const temporaryPath = cacheDir + "/" + temporaryName;
                const geometry = StashWorkflow.grimGeometry(client);
                const scale = StashWorkflow.previewScale(client.width, previewWidth);
                Proc.runCommand(null, ["grim", "-g", geometry, "-s", String(scale), "-t", "png", "-l", "6", temporaryPath], (grimOutput, grimExitCode) => {
                    if (grimExitCode !== 0) {
                        log.warn("Preview capture failed for client", id, grimOutput || "grim failed");
                        removeOwnedCacheFile(temporaryName);
                        done(false, "", "");
                        return;
                    }
                    done(true, temporaryPath, finalPath);
                }, 0, 15000);
            }, 0, 5000);
        });
    }

    function finishStash(message, isError) {
        stashBusy = false;
        publishStatus();
        if (isError) {
            log.warn(message);
            ToastService?.showError("Scratchpad stash failed", message);
        } else {
            log.info(message);
        }
    }

    function dispatchStash(client, captured, temporaryPath, finalPath) {
        queryFocusedClient((focusedAgain, output) => {
            if (!focusedAgain || focusedAgain.id !== client.id) {
                if (captured)
                    removeOwnedCacheFile(PreviewCache.temporaryFileNameForClient(client.id));
                finishStash("Focused window changed before it could be stashed", true);
                return;
            }
            MangoService.dispatch("minimized client," + client.id, reply => {
                let success = false;
                try {
                    success = JSON.parse(reply).success === true;
                } catch (e) {}
                if (!success) {
                    if (captured)
                        removeOwnedCacheFile(PreviewCache.temporaryFileNameForClient(client.id));
                    finishStash("Mango rejected the minimized dispatcher" + (reply ? ": " + reply : ""), true);
                    return;
                }
                if (!captured) {
                    discardPreview(client.id);
                    finishStash("Stashed Mango client " + client.id + " without preview", false);
                    return;
                }
                Proc.runCommand(null, ["mv", "-f", temporaryPath, finalPath], (moveOutput, moveExitCode) => {
                    if (moveExitCode !== 0) {
                        log.warn("Stashed client", client.id, "but could not finalize its preview", moveOutput || "mv failed");
                        removeOwnedCacheFile(PreviewCache.temporaryFileNameForClient(client.id));
                        discardPreview(client.id);
                        finishStash("Stashed Mango client " + client.id + " without a new preview", false);
                        return;
                    }
                    recordPreview(client.id, finalPath);
                    finishStash("Stashed Mango client " + client.id + " with preview", false);
                }, 0, 5000);
            });
        });
    }

    function stashFocusedClient() {
        if (stashBusy)
            return "BUSY: a stash action is already running";
        if (!CompositorService.isMango)
            return "UNSUPPORTED: Scratchpad Helper requires MangoWM";
        if (!MangoService.available)
            return "UNAVAILABLE: DMS MangoService is not connected";
        stashBusy = true;
        publishStatus();
        queryFocusedClient((client, output) => {
            if (!client) {
                finishStash("Could not identify Mango's focused client", true);
                return;
            }
            if (client.is_minimized === true || client.is_visible !== true) {
                finishStash("The focused Mango client is not a visible window", true);
                return;
            }
            capturePreview(client, (captured, temporaryPath, finalPath) => dispatchStash(client, captured, temporaryPath, finalPath));
        });
        return "STASH_STARTED";
    }

    function activateClient(clientId) {
        const id = PreviewCache.normalizeClientId(clientId);
        if (!id || !CompositorService.isMango || !MangoService.available)
            return false;
        const source = MangoService.windows || [];
        const client = source.find(candidate => String(candidate?.id) === id);
        if (!client)
            return false;

        if (client.is_namedscratchpad === true) {
            const associations = NamedRuntime.classify(source, namedDefinitionStore,
                namedManagerEnabled, namedConfigSynchronized, NamedDefinitions);
            const association = associations[id];
            if (!association?.command)
                return false;
            MangoService.dispatch(association.command, reply => {
                let success = false;
                try { success = JSON.parse(reply).success === true; } catch (e) {}
                if (!success)
                    log.warn("Could not toggle managed named scratchpad", association.definitionId, reply || "no reply");
            });
            return true;
        }

        if (client.is_scratchpad !== true)
            return false;

        // Restore the exact scratchpad window by Mango client ID
        MangoService.dispatch("focusid client," + id, reply => {
            let success = false;
            try {
                success = JSON.parse(reply).success === true;
            } catch (e) {}
            if (!success)
                log.warn("Could not restore and focus Mango client", id, reply || "no reply");
        });
        return true;
    }

    onNamedDefinitionStoreChanged: rebuildModel()
    onNamedManagerEnabledChanged: rebuildModel()
    onNamedGeneratedHashChanged: rebuildModel()
    onNamedAppliedHashChanged: rebuildModel()
    onNamedConfigSynchronizedChanged: rebuildModel()

    FileView {
        id: namedConfigReader
        path: root.namedConfigUrl
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.namedConfigContent = text();
            root.namedConfigReadable = true;
            root.rebuildModel();
        }
        onLoadFailed: error => {
            root.namedConfigContent = "";
            root.namedConfigReadable = false;
            root.rebuildModel();
        }
    }

    FolderListModel {
        id: cacheRootFolder
        folder: ""
        showDirs: true
        showFiles: true
        showHidden: false
        showDotAndDotDot: false
        nameFilters: ["instance-*", "client-*.png", "capture-*.tmp.png"]

        onCountChanged: root.reconcileInstanceDirectories()
        onStatusChanged: root.reconcileInstanceDirectories()
    }

    FolderListModel {
        id: previewFolder
        folder: ""
        showDirs: false
        showFiles: true
        showHidden: false
        showDotAndDotDot: false
        nameFilters: ["client-*.png", "capture-*.tmp.png"]

        onCountChanged: root.refreshPreviewEntries()
        onStatusChanged: root.refreshPreviewEntries()
    }

    Connections {
        target: MangoService

        function onWindowsChanged() {
            root.reconcileCache();
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

    Connections {
        target: pluginService

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return;
            root.publishStatus();
            root.rebuildModel();
        }

        function onGlobalVarChanged(changedPluginId, varName) {
            if (changedPluginId !== root.pluginId || varName !== "activateRequest")
                return;
            const request = pluginService?.getGlobalVar(root.pluginId, "activateRequest", null);
            if (request?.clientId !== undefined)
                root.activateClient(request.clientId);
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

        function stash(): string {
            return root.stashFocusedClient();
        }

        function activate(clientId: int): string {
            return root.activateClient(clientId) ? "ACTIVATE_REQUESTED: " + clientId : "ERROR: unknown scratchpad client " + clientId;
        }

        function status(): string {
            if (!CompositorService.isMango)
                return "unsupported\t0";
            if (!MangoService.available)
                return "unavailable\t0";
            const clients = pluginService?.getGlobalVar(root.pluginId, "clients", []) ?? [];
            return "active\t" + clients.length + "\tpreviews=" + (previewsEnabled && grimAvailable ? "available" : "fallback") + "\tstash=" + (stashBusy ? "busy" : "ready");
        }
    }

    Component.onCompleted: {
        log.info("Started; using DMS MangoService.windows");
        setupCache();
        rebuildModel();
    }

    Component.onDestruction: log.info("Stopped")
}
