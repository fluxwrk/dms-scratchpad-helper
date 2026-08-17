import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import Quickshell.Io
import qs.Common
import qs.Services
import "NamedScratchpadDefinitions.js" as Definitions

Item {
    id: root
    width: 0
    height: 0
    visible: false

    readonly property string pluginId: "scratchpadHelper"
    readonly property string includeLine: "source-optional=~/.config/mango/scratchpad-helper.conf"
    // StandardPaths and FileView use URLs. External programs require decoded
    // native paths. Keep both forms named and cross the boundary only here.
    readonly property url configBaseUrl: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string configDirPath: toLocalPath(configBaseUrl) + "/mango"
    readonly property string targetPath: configDirPath + "/scratchpad-helper.conf"
    readonly property string mainConfigPath: configDirPath + "/config.conf"
    readonly property url targetFileUrl: toFileUrl(targetPath)
    readonly property url mainConfigFileUrl: toFileUrl(mainConfigPath)
    readonly property var pluginSettings: SettingsData.getPluginSettingsForPlugin(pluginId)
    readonly property bool managerEnabled: SettingsData.getPluginSetting(pluginId, "namedManagerEnabled", false)
    property var definitionStore: pluginSettings.namedManagerStore === undefined ? null : pluginSettings.namedManagerStore
    readonly property string knownHash: SettingsData.getPluginSetting(pluginId, "namedManagerGeneratedHash", "")
    readonly property string appliedHash: SettingsData.getPluginSetting(pluginId, "namedManagerAppliedHash", "")

    property string status: "Checking configuration…"
    property string detail: ""
    property string errorText: ""
    property string errorSummary: ""
    property bool busy: false
    property bool targetExists: false
    property bool targetScanned: false
    property string targetScanError: ""
    property string targetContent: ""
    property bool mainConfigExists: false
    property bool mainScanned: false
    property string mainScanError: ""
    property bool includeConfigured: false
    property bool generatedValid: false
    property bool reloadNeeded: false
    property string ownership: "unknown"
    property bool pendingChanges: false
    property int definitionCount: 0
    property string storeError: ""

    property string _candidatePath: ""
    property string _candidateContent: ""
    property string _previousContent: ""
    property bool _previousExisted: false
    property string _transactionHash: ""
    property bool _rollingBack: false

    signal transactionFinished(bool success)

    function toLocalPath(fileUrl) {
        return Paths.strip(fileUrl);
    }

    function toFileUrl(localPath) {
        return Paths.toFileUrl(localPath);
    }

    function storedDefinitions() {
        const loaded = Definitions.loadStore(definitionStore);
        if (!loaded.valid)
            return null;
        return loaded.store.definitions;
    }

    function recomputeContentState() {
        const definitions = storedDefinitions();
        definitionCount = definitions === null ? 0 : definitions.length;
        storeError = definitions === null ? "Stored named scratchpads could not be read." : "";
        if (!targetScanned) {
            pendingChanges = false;
            return;
        }
        const state = Definitions.generatedContentState(definitionStore,
            targetExists ? targetContent : null, knownHash);
        ownership = state.state === "conflict" ? "conflict" : ownership;
        if (state.state === "invalid")
            storeError = "Some stored named scratchpads need attention.";
        pendingChanges = state.state === "pending";
        generatedValid = state.state === "current" && includeConfigured;
        reloadNeeded = generatedValid && appliedHash !== knownHash;
    }

    function refresh() {
        targetScanned = false;
        mainScanned = false;
        targetReader.reload();
        mainReader.reload();
    }

    function _detectInclude(content) {
        return Definitions.detectsExpectedInclude(content, root.targetPath);
    }

    function _updateSummary() {
        recomputeContentState();
        if (!managerEnabled) {
            status = "Manager disabled";
            detail = "";
            return;
        }
        if (!targetScanned || !mainScanned) {
            status = "Checking configuration…";
            detail = "";
            return;
        }
        if (targetScanError || mainScanError) {
            status = "Can't check Mango configuration";
            detail = "Check that your Mango configuration files are readable.";
            return;
        }
        if (ownership === "conflict") {
            status = "Config file was changed";
            detail = "Scratchpad Helper won't overwrite your changes.";
            return;
        }
        if (storeError) {
            status = "Definitions need attention";
            detail = storeError;
            return;
        }
        if (errorText) {
            status = errorSummary || "Configuration error";
            detail = "Review the details, correct the problem, and try again.";
            return;
        }
        if (!includeConfigured) {
            status = "Setup required";
            detail = "Add the include to your Mango config.";
            return;
        }
        if (!targetExists) {
            status = "Generate config";
            detail = "Create the Scratchpad Helper config file.";
            return;
        }
        if (pendingChanges) {
            status = "Changes ready to generate";
            detail = "Generate the config to apply your definition changes.";
            return;
        }
        status = "Configuration ready";
        detail = reloadNeeded ? "Reload Mango to apply the validated config." : "Mango config is valid.";
    }

    function generate() {
        if (!managerEnabled || busy)
            return;
        errorText = "";
        errorSummary = "";
        if (targetScanError || mainScanError) {
            errorText = targetScanError || mainScanError;
            _updateSummary();
            _finalizeOperation(false);
            return;
        }
        const definitions = storedDefinitions();
        if (definitions === null) {
            errorText = "The stored named-scratchpad schema is unsupported or malformed.";
            generatedValid = false;
            _updateSummary();
            _finalizeOperation(false);
            return;
        }
        const result = Definitions.serializeDefinitions(definitions);
        if (!result.valid) {
            errorText = result.errors.length ? result.errors[0].message : "Managed definitions are invalid.";
            generatedValid = false;
            _updateSummary();
            _finalizeOperation(false);
            return;
        }
        const ownershipResult = Definitions.ownershipState(targetExists ? targetContent : null, knownHash);
        ownership = ownershipResult.state;
        if (ownership === "conflict") {
            errorText = "The existing helper file does not match Scratchpad Helper's last successful generation.";
            _updateSummary();
            _finalizeOperation(false);
            return;
        }

        busy = true;
        generatedValid = false;
        reloadNeeded = false;
        _candidateContent = result.content;
        _transactionHash = Definitions.contentHash(result.content);
        _previousExisted = targetExists;
        _previousContent = targetContent;
        _candidatePath = targetPath + ".tmp." + Date.now() + "." + Math.floor(Math.random() * 0x1000000).toString(16);
        _run(["mkdir", "-p", configDirPath], function(exitCode, output) {
            if (exitCode !== 0) {
                root._fail("Could not create Mango's configuration directory. " + output);
                return;
            }
            try {
                candidateWriter.path = root.toFileUrl(root._candidatePath);
                candidateWriter.setText(root._candidateContent);
            } catch (error) {
                root._cleanupCandidate();
                root._fail("Could not start the candidate write: " + error);
            }
        });
    }

    function _validateCandidate() {
        _run(["mango", "-c", _candidatePath, "-p"], function(exitCode, output) {
            if (!root._parserAccepted(exitCode, output)) {
                root._cleanupCandidate();
                root._fail("Mango rejected the generated candidate. " + root._cleanDiagnostic(output), "Couldn't validate the generated config.");
                return;
            }
            root._run(["mv", "--", root._candidatePath, root.targetPath], function(moveCode, moveOutput) {
                if (moveCode !== 0) {
                    root._cleanupCandidate();
                    root._fail("Atomic replacement failed. " + moveOutput);
                    return;
                }
                if (root.includeConfigured && root.mainConfigExists)
                    root._validateIntegrated();
                else
                    root._completeSuccess();
            });
        });
    }

    function _validateIntegrated() {
        _run(["mango", "-c", mainConfigPath, "-p"], function(exitCode, output) {
            if (root._parserAccepted(exitCode, output)) {
                root._completeSuccess();
                return;
            }
            root.errorText = "The complete Mango configuration failed validation. The previous helper file was restored.";
            root.errorSummary = "Couldn't validate the generated config.";
            root._rollback(root._cleanDiagnostic(output));
        });
    }

    function _parserAccepted(exitCode, output) {
        if (exitCode !== 0)
            return false;
        const diagnostic = _cleanDiagnostic(output);
        return !/(^|\b)(error|unknown keyword|invalid line|failed to open)(\b|:)/i.test(diagnostic);
    }

    function _cleanDiagnostic(output) {
        return String(output || "").replace(/\x1b\[[0-9;]*m/g, "").trim();
    }

    function _rollback(diagnostic) {
        _rollingBack = true;
        if (diagnostic)
            errorText += " " + diagnostic;
        if (_previousExisted) {
            try {
                rollbackWriter.path = toFileUrl(targetPath);
                rollbackWriter.setText(_previousContent);
            } catch (error) {
                _fail("Integrated validation failed and restoring the previous helper file could not start: " + error);
            }
            return;
        }
        _run(["rm", "-f", "--", targetPath], function(exitCode, output) {
            if (exitCode !== 0) {
                root._fail(root.errorText + " Removing the newly created helper file also failed: " + output);
                return;
            }
            root._fail(root.errorText);
        });
    }

    function _completeSuccess() {
        generatedValid = true;
        reloadNeeded = includeConfigured;
        errorText = "";
        errorSummary = "";
        targetExists = true;
        targetContent = _candidateContent;
        ownership = "owned";
        pendingChanges = false;
        try {
            SettingsData.setPluginSetting(pluginId, "namedManagerGeneratedHash", _transactionHash);
        } catch (error) {
            generatedValid = false;
            reloadNeeded = false;
            errorText = "The generated file validated, but its ownership state could not be saved: " + error;
            errorSummary = "Couldn't save generated-config ownership.";
            _updateSummary();
            _finalizeOperation(false);
            return;
        }
        _updateSummary();
        _finalizeOperation(true);
    }

    function _fail(message, summary) {
        generatedValid = false;
        errorText = String(message || "Configuration transaction failed.").trim();
        if (summary)
            errorSummary = summary;
        _updateSummary();
        _finalizeOperation(false);
    }

    function _finalizeOperation(success) {
        busy = false;
        _rollingBack = false;
        transactionFinished(success);
    }

    function _cleanupCandidate() {
        if (_candidatePath) {
            _run(["rm", "-f", "--", _candidatePath], function() {});
        }
    }

    function _cleanupStaleCandidates() {
        if (!managerEnabled || busy || staleCandidates.status !== FolderListModel.Ready)
            return;
        for (let i = 0; i < staleCandidates.count; ++i) {
            const path = configDirPath + "/" + staleCandidates.get(i, "fileName");
            if (path === _candidatePath)
                continue;
            const reader = staleReaderFactory.createObject(root, {"cleanupPath": path});
            if (!reader)
                return;
        }
    }

    function reloadMango() {
        if (!managerEnabled || !generatedValid || !includeConfigured || busy)
            return;
        busy = true;
        _run(["mango", "-c", mainConfigPath, "-p"], function(exitCode, output) {
            if (!root._parserAccepted(exitCode, output)) {
                root._fail("Mango configuration no longer validates; reload was not requested. " + root._cleanDiagnostic(output));
                return;
            }
            MangoService.dispatch("reload_config", function(reply) {
                let accepted = false;
                try { accepted = JSON.parse(reply).success === true; } catch (_) {}
                if (!accepted) {
                    root._fail("Mango did not accept the reload request.");
                    return;
                }
                root.reloadNeeded = false;
                SettingsData.setPluginSetting(root.pluginId, "namedManagerAppliedHash", root.knownHash);
                root.status = "Reload requested";
                root.detail = "Mango is processing its configuration.";
                root._finalizeOperation(true);
            });
        });
    }

    function copyIncludeLine() {
        _run([Proc.dmsBin, "cl", "copy", includeLine], function() {});
    }

    function _run(command, callback) {
        let process = null;
        try {
            process = processFactory.createObject(root, {"command": command, "completion": callback});
            if (!process) {
                callback(-1, "Could not create the process runner.");
                return;
            }
            process.running = true;
        } catch (error) {
            if (process)
                process.destroy();
            callback(-1, String(error));
        }
    }

    Component.onCompleted: {
        if (managerEnabled && definitionStore === null)
            SettingsData.setPluginSetting(pluginId, "namedManagerStore", Definitions.defaultStore());
        refresh();
    }
    onManagerEnabledChanged: {
        if (managerEnabled && definitionStore === null)
            SettingsData.setPluginSetting(pluginId, "namedManagerStore", Definitions.defaultStore());
        _updateSummary();
    }
    onDefinitionStoreChanged: _updateSummary()
    onKnownHashChanged: _updateSummary()
    onAppliedHashChanged: _updateSummary()

    FileView {
        id: targetReader
        path: root.targetFileUrl
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
        }
        onLoaded: {
            root.targetScanError = "";
            root.targetExists = true;
            root.targetContent = text();
            root.targetScanned = true;
            root.ownership = Definitions.ownershipState(root.targetContent, root.knownHash).state;
            root._updateSummary();
        }
        onLoadFailed: error => {
            const missing = error === FileViewError.FileNotFound;
            root.targetExists = !missing;
            root.targetContent = "";
            root.targetScanned = true;
            root.targetScanError = missing ? "" : "Scratchpad Helper cannot safely read the existing helper file: " + FileViewError.toString(error);
            root.ownership = missing ? "absent" : "conflict";
            root._updateSummary();
        }
    }

    FileView {
        id: mainReader
        path: root.mainConfigFileUrl
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: {
            reload();
        }
        onLoaded: {
            root.mainScanError = "";
            root.mainConfigExists = true;
            root.includeConfigured = root._detectInclude(text());
            root.mainScanned = true;
            root._updateSummary();
        }
        onLoadFailed: error => {
            const missing = error === FileViewError.FileNotFound;
            root.mainConfigExists = !missing;
            root.includeConfigured = false;
            root.mainScanned = true;
            root.mainScanError = missing ? "" : "Scratchpad Helper cannot inspect Mango's main config: " + FileViewError.toString(error);
            root._updateSummary();
        }
    }

    FileView {
        id: candidateWriter
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onSaved: {
            root._validateCandidate();
        }
        onSaveFailed: error => {
            root._cleanupCandidate();
            root._fail("Could not write the generated candidate: " + error);
        }
    }

    FileView {
        id: rollbackWriter
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onSaved: {
            root._fail(root.errorText);
        }
        onSaveFailed: error => {
            root._fail("Integrated validation failed and restoring the previous helper file also failed: " + error);
        }
    }

    FolderListModel {
        id: staleCandidates
        folder: root.managerEnabled ? root.toFileUrl(root.configDirPath) : ""
        showDirs: false
        showFiles: true
        showHidden: true
        showDotAndDotDot: false
        nameFilters: ["scratchpad-helper.conf.tmp.*"]
        onStatusChanged: root._cleanupStaleCandidates()
    }

    Component {
        id: staleReaderFactory
        FileView {
            property string cleanupPath: ""
            path: root.toFileUrl(cleanupPath)
            blockLoading: true
            printErrors: false
            onLoaded: {
                if (text().startsWith("# Generated by Scratchpad Helper. Do not edit by hand.\n"))
                    root._run(["rm", "-f", "--", cleanupPath], function() {});
                destroy();
            }
            onLoadFailed: error => destroy()
        }
    }

    Component {
        id: processFactory
        Process {
            id: processRoot
            property var completion: null
            property bool exitSeen: false
            property bool stdoutSeen: false
            property bool stderrSeen: false
            property int resultCode: -1
            property bool finished: false
            property Timer timeoutTimer: Timer {
                interval: 10000
                running: processRoot.running
                repeat: false
                onTriggered: {
                    processRoot.running = false;
                    processRoot.resultCode = 124;
                    processRoot.exitSeen = true;
                    processRoot.stdoutSeen = true;
                    processRoot.stderrSeen = true;
                    processRoot.maybeFinish();
                }
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    processRoot.stdoutSeen = true;
                    processRoot.maybeFinish();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    processRoot.stderrSeen = true;
                    processRoot.maybeFinish();
                }
            }
            onExited: exitCode => {
                resultCode = exitCode;
                exitSeen = true;
                maybeFinish();
            }
            function maybeFinish() {
                if (finished || !exitSeen || !stdoutSeen || !stderrSeen)
                    return;
                finished = true;
                timeoutTimer.stop();
                const output = String(stdout.text || "") + String(stderr.text || "");
                if (completion)
                    completion(resultCode, output);
                destroy();
            }

        }
    }
}
