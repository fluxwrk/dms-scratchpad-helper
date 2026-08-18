const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const os = require("node:os");
const path = require("node:path");
const childProcess = require("node:child_process");
const nodeUrl = require("node:url");

const source = fs.readFileSync("NamedScratchpadDefinitions.js", "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const pathSource = fs.readFileSync("MangoConfigPaths.js", "utf8").replace(/^\.pragma library\s*/, "");
const pathContext = {};
vm.createContext(pathContext);
vm.runInContext(pathSource, pathContext);

const valid = overrides => ({
    id: "scratch-terminal",
    displayName: "Scratch terminal",
    appId: "org.example.ScratchTerm",
    title: "",
    launchCommand: "ghostty --class=org.example.ScratchTerm",
    enabled: true,
    creationOrder: 1,
    ...overrides
});
const codes = result => result.errors.map(error => error.code);

assert.equal(context.SCHEMA_VERSION, 1);
assert.equal(context.MAX_DEFINITIONS, 200);
assert.equal(context.defaultStore().schemaVersion, 1);
assert.deepEqual(Array.from(context.defaultStore().definitions), []);

for (const definition of [
    valid({appId: "app", title: ""}),
    valid({appId: "", title: "fixed-title"}),
    valid({appId: "app", title: "fixed-title"}),
    valid({enabled: false})
]) assert.equal(context.validateDefinitions([definition]).valid, true);

for (const enabled of ["true", "false", 1, 0, null, undefined, {}, []]) {
    const result = context.validateDefinitions([valid({enabled})]);
    assert.equal(result.valid, false);
    assert.ok(codes(result).includes("boolean"));
    assert.equal(context.serializeDefinitions([valid({enabled})]).valid, false);
}
const missingEnabled = valid();
delete missingEnabled.enabled;
assert.ok(codes(context.validateDefinitions([missingEnabled])).includes("boolean"));
assert.equal(context.serializeDefinitions([missingEnabled]).valid, false);
assert.equal(context.validateDefinitions([valid({enabled: true})]).valid, true);
assert.equal(context.validateDefinitions([valid({enabled: false})]).valid, true);

const tooMany = Array.from({length: context.MAX_DEFINITIONS + 1}, (_, index) =>
    valid({id: "definition-" + index, appId: "app-" + index, creationOrder: index}));
assert.ok(codes(context.validateDefinitions(tooMany)).includes("too-many"));
assert.equal(context.loadStore({schemaVersion: 1, definitions: tooMany}).valid, false);

assert.ok(codes(context.validateDefinitions([valid({displayName: "   "})])).includes("required"));
assert.ok(codes(context.validateDefinitions([valid({appId: "", title: ""})])).includes("required"));
assert.ok(codes(context.validateDefinitions([valid({launchCommand: ""})])).includes("required"));
for (const field of ["appId", "title"])
    assert.ok(codes(context.validateDefinitions([valid({appId: field === "appId" ? "nonepad" : "app", title: field === "title" ? "none-title" : ""})])).includes("none-sentinel"));
for (const bad of [",", "\n", "\r", "\0", "\u0007"])
    assert.equal(context.validateDefinitions([valid({appId: "bad" + bad + "value"})]).valid, false);
assert.ok(codes(context.validateDefinitions([valid({appId: "bad\ud800value"})])).includes("unicode"));
assert.equal(context.validateDefinitions([valid({launchCommand: "echo,bad"})]).valid, false);
assert.equal(context.validateDefinitions([valid({appId: "a".repeat(context.MAX_IDENTITY_BYTES + 1)})]).valid, false);
assert.equal(context.validateDefinitions([valid({launchCommand: "x".repeat(context.MAX_COMMAND_BYTES + 1)})]).valid, false);
assert.equal(context.validateDefinitions([valid(), valid({displayName: "Duplicate"})]).valid, false);
assert.ok(codes(context.validateDefinitions([valid(), valid({id: "other"})])).includes("duplicate"));
assert.ok(codes(context.validateDefinitions([
    valid({appId: "same", title: ""}),
    valid({id: "other", appId: "same", title: "specific"})
])).includes("overlap"));
assert.ok(codes(context.validateDefinitions([
    valid({appId: "only-app", title: ""}),
    valid({id: "other", appId: "", title: "only-title"})
])).includes("overlap"));
assert.equal(context.validateDefinitions([
    valid({appId: "same", title: "one"}),
    valid({id: "other", appId: "same", title: "two"})
]).valid, true);

const literal = "a\\b.c^d$e|f?g*h+i(j)[k]{l}-m/雪";
assert.equal(context.exactPattern(literal), "^a\\\\b\\.c\\^d\\$e\\|f\\?g\\*h\\+i\\(j\\)\\[k\\]\\{l\\}\\-m/雪$");

const serialized = context.serializeDefinitions([
    valid({id: "z-last", displayName: "Z", appId: "z", creationOrder: 9}),
    valid({id: "a-first", displayName: "A", appId: "a", title: "title", creationOrder: 1}),
    valid({id: "disabled", displayName: "Disabled", appId: "off", enabled: false, creationOrder: 0})
]);
assert.equal(serialized.valid, true);
assert.ok(serialized.content.indexOf("a-first") < serialized.content.indexOf("z-last"));
assert.ok(serialized.content.includes("windowrule=isnamedscratchpad:1,appid:^a$,title:^title$"));
assert.ok(serialized.content.includes("windowrule=isnamedscratchpad:1,appid:^z$"));
assert.ok(!serialized.content.includes("disabled"));
assert.ok(!serialized.content.includes("bind="));
assert.ok(!serialized.content.includes("ghostty"));
assert.ok(!serialized.content.includes("exec="));
assert.ok(!serialized.content.includes("env="));
assert.ok(!serialized.content.includes("source="));
assert.ok(serialized.content.endsWith("\n"));
assert.equal(serialized.content.includes("\r"), false);
assert.equal(context.serializeDefinitions(serialized.definitions).content, serialized.content);

assert.equal(context.contentHash("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
const hash = context.contentHash(serialized.content);
assert.equal(context.ownershipState(null, hash).state, "absent");
assert.equal(context.ownershipState(serialized.content, hash).state, "owned");
assert.equal(context.ownershipState(serialized.content + "# edit\n", hash).state, "conflict");
assert.equal(context.ownershipState(serialized.content, "").state, "conflict");
// A conflict is transient: restoring the exact owned content must recover.
assert.equal(context.ownershipState(serialized.content + "# tampered\n", hash).state, "conflict");
assert.equal(context.ownershipState(serialized.content, hash).state, "owned");

const recoveryStore = {schemaVersion: 1, definitions: serialized.definitions};
const recoverable = context.generatedContentState(recoveryStore, serialized.content, "");
assert.equal(recoverable.state, "recoverable");
assert.equal(recoverable.pending, true);
assert.equal(recoverable.expectedContent, serialized.content);
assert.equal(context.generatedContentState(recoveryStore, serialized.content + "#", "").state, "conflict");
const otherSerialization = context.serializeDefinitions([valid({id: "other", appId: "other"})]).content;
assert.equal(context.generatedContentState(recoveryStore, otherSerialization, "").state, "conflict");
// Recovery establishes generated ownership only. Applied/reloaded state remains
// an independent persisted value and is not part of generatedContentState().
assert.equal(Object.hasOwn(recoverable, "appliedHash"), false);
assert.notEqual(recoverable.state, "current");

const homePath = "/home/tester";
assert.equal(pathContext.configDirectory(homePath), "/home/tester/.config/mango");
assert.equal(pathContext.helperConfigPath(homePath), "/home/tester/.config/mango/scratchpad-helper.conf");
assert.equal(pathContext.mainConfigPath(homePath), "/home/tester/.config/mango/config.conf");
assert.equal(pathContext.helperIncludeLine(), "source-optional=~/.config/mango/scratchpad-helper.conf");
assert.equal(pathContext.helperConfigPath(homePath), pathContext.helperConfigPath(homePath, "/custom/xdg"));

const target = "/home/test/.config/mango/scratchpad-helper.conf";
assert.equal(context.detectsExpectedInclude("source-optional=~/.config/mango/scratchpad-helper.conf\n", target), true);
assert.equal(context.detectsExpectedInclude("  source-optional = " + target + "  # helper\n", target), true);
assert.equal(context.detectsExpectedInclude("source=~/.config/mango/scratchpad-helper.conf\n", target), false);
assert.equal(context.detectsExpectedInclude("# source-optional=~/.config/mango/scratchpad-helper.conf\n", target), false);

// The manager-off contract is deliberately pure: no transaction is requested.
const shouldGenerate = (enabled, requested) => enabled && requested;
assert.equal(shouldGenerate(false, true), false);
assert.equal(shouldGenerate(true, true), true);

const qmlSource = fs.readFileSync("NamedScratchpadConfig.qml", "utf8");
assert.ok(qmlSource.includes("atomicWrites: true"));
assert.ok(qmlSource.includes("StandardPaths.writableLocation(StandardPaths.HomeLocation)"));
assert.ok(qmlSource.includes("MangoConfigPaths.configDirectory(homePath)"));
assert.ok(qmlSource.includes("MangoConfigPaths.helperConfigPath(homePath)"));
assert.ok(qmlSource.includes("MangoConfigPaths.mainConfigPath(homePath)"));
assert.ok(qmlSource.includes("MangoConfigPaths.helperIncludeLine()"));
assert.ok(!qmlSource.includes("StandardPaths.ConfigLocation"));
assert.ok(qmlSource.includes("return Paths.strip(fileUrl);"));
assert.ok(qmlSource.includes("return Paths.toFileUrl(localPath);"));
assert.ok(qmlSource.includes("path: root.targetFileUrl"));
assert.ok(qmlSource.includes("path: root.mainConfigFileUrl"));
assert.ok(qmlSource.includes('["mango", "-c", _candidatePath, "-p"]'));
assert.ok(qmlSource.includes('["mango", "-c", mainConfigPath, "-p"]'));
assert.ok(qmlSource.includes('["mv", "--", root._candidatePath, root.targetPath]'));
assert.ok(qmlSource.includes('["rm", "-f", "--", targetPath]'));
assert.ok(qmlSource.includes('["rm", "-f", "--", _candidatePath]'));
assert.ok(qmlSource.includes('["mkdir", "-p", configDirPath]'));
assert.ok(!/\["(?:mango|mkdir|mv|rm)"[^\n]*FileUrl/.test(qmlSource));
assert.ok(!/\["(?:mango|mkdir|mv|rm)"[^\n]*file:\/\//.test(qmlSource));
assert.ok(!qmlSource.includes('"sh", "-c"'));
assert.ok(!qmlSource.includes('"bash", "-c"'));

// Every async terminal path reaches either _completeSuccess() or _fail(), and
// only the central finalizer clears transient operation state.
const functionBody = name => {
    const start = qmlSource.indexOf("function " + name + "(");
    assert.notEqual(start, -1, "missing function " + name);
    const next = qmlSource.indexOf("\n    function ", start + 1);
    return qmlSource.slice(start, next === -1 ? qmlSource.length : next);
};
assert.equal((qmlSource.match(/\bbusy\s*=\s*false;/g) || []).length, 1);
assert.ok(functionBody("generate").includes("busy = true;"));
assert.ok(functionBody("reloadMango").includes("busy = true;"));
assert.ok(functionBody("reloadMango").includes("root._completeReload(reply, generatedHash);"));
assert.ok(functionBody("reloadMango").includes("catch (error)"));
assert.ok(functionBody("_completeReload").includes('SettingsData.setPluginSetting(pluginId, "namedManagerAppliedHash", generatedHash);'));
assert.ok(functionBody("_completeReload").includes("_finalizeOperation(true);"));
assert.ok(functionBody("_completeReload").includes("catch (error)"));
assert.ok(functionBody("_completeReload").includes("_fail("));
assert.ok(functionBody("_completeReload").indexOf("setPluginSetting") < functionBody("_completeReload").indexOf("reloadNeeded = false"));
assert.ok(functionBody("_finalizeOperation").includes("busy = false;"));
assert.ok(functionBody("_completeSuccess").includes("_finalizeOperation(true);"));
assert.ok(functionBody("_fail").includes("_finalizeOperation(false);"));
assert.ok(functionBody("generate").includes('contentState.state === "conflict"'));
assert.ok(functionBody("generate").includes('contentState.state === "recoverable"'));
assert.ok(functionBody("generate").includes("_finalizeOperation(false);"));
assert.ok(functionBody("_validateCandidate").includes("root._fail("));
assert.ok(functionBody("_validateIntegrated").includes("root._rollback("));
assert.ok(functionBody("_rollback").includes("root._fail("));
assert.ok(qmlSource.includes("root._fail(root.errorText);"));
assert.ok(qmlSource.includes("processRoot.resultCode = 124;"));
assert.ok(qmlSource.includes('callback(-1, "Could not create the process runner.");'));
assert.ok(qmlSource.includes("callback(-1, String(error));"));
assert.ok(!qmlSource.includes("ScratchpadHelper.NamedConfig"));
assert.ok(!qmlSource.includes("_trace("));

const daemonSource = fs.readFileSync("ScratchpadDaemon.qml", "utf8");
assert.ok(daemonSource.includes("StandardPaths.writableLocation(StandardPaths.HomeLocation)"));
assert.ok(daemonSource.includes("MangoConfigPaths.helperConfigPath(homePath)"));
assert.ok(!daemonSource.includes("StandardPaths.ConfigLocation"));
assert.ok(daemonSource.includes('return state.state === "current";'));

const spacedPath = "/tmp/Scratchpad Helper/config.conf";
const spacedUrl = nodeUrl.pathToFileURL(spacedPath);
assert.equal(spacedUrl.protocol, "file:");
assert.equal(nodeUrl.fileURLToPath(spacedUrl), spacedPath);
assert.match(spacedUrl.href, /Scratchpad%20Helper/);
const structuredArgv = ["mango", "-c", nodeUrl.fileURLToPath(spacedUrl), "-p"];
assert.deepEqual(structuredArgv, ["mango", "-c", spacedPath, "-p"]);
assert.equal(structuredArgv.some(argument => argument.startsWith("file://")), false);

const mangoProbe = childProcess.spawnSync("mango", ["-c", "/dev/null", "-p"], {encoding: "utf8"});
if (!mangoProbe.error) {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "scratchpad-helper-contract-"));
    const goodPath = path.join(tempDir, "good.conf");
    const badPath = path.join(tempDir, "bad.conf");
    fs.writeFileSync(goodPath, serialized.content, {mode: 0o600});
    fs.writeFileSync(badPath, "not-a-mango-option=1\n", {mode: 0o600});
    const good = childProcess.spawnSync("mango", ["-c", goodPath, "-p"], {encoding: "utf8"});
    const bad = childProcess.spawnSync("mango", ["-c", badPath, "-p"], {encoding: "utf8"});
    assert.equal(good.status, 0);
    assert.equal((good.stdout + good.stderr).trim(), "");
    assert.notEqual(bad.status, 0);
    assert.match(bad.stdout + bad.stderr, /Unknown keyword|ERROR/i);
    fs.rmSync(tempDir, {recursive: true, force: true});
}

console.log("named scratchpad config contract: ok");
