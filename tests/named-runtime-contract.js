const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

function load(file) {
    const context = {};
    vm.createContext(context);
    vm.runInContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*/, ""), context);
    return context;
}

const definitions = load("NamedScratchpadDefinitions.js");
const runtime = load("NamedScratchpadRuntime.js");
const definition = overrides => ({
    id: "ghostty-id", displayName: "Ghostty", appId: "com.example.ghostty",
    title: "", launchCommand: "ghostty --class=com.example.ghostty", enabled: true,
    creationOrder: 0, ...overrides
});
const store = items => ({schemaVersion: 1, definitions: items});
const named = (id, appid, title = "") => ({id, appid, title, is_namedscratchpad: true});
const classify = (clients, rawStore = store([definition()]), enabled = true, synchronized = true) =>
    runtime.classify(clients, rawStore, enabled, synchronized, definitions);

let result = classify([named(1, "com.example.ghostty")]);
assert.equal(result["1"].definitionId, "ghostty-id");
assert.equal(result["1"].command, "toggle_named_scratchpad,^com\\.example\\.ghostty$,none,ghostty --class=com.example.ghostty");
assert.deepEqual(Object.keys(classify([named(1, "external")])), []);
assert.deepEqual(Object.keys(classify([named(1, "com.example.ghostty")], undefined, false)), []);
assert.deepEqual(Object.keys(classify([named(1, "com.example.ghostty")], store([definition({enabled: false})]))), []);
assert.deepEqual(Object.keys(classify([named(1, "com.example.ghostty")], {schemaVersion: 99, definitions: []})), []);
assert.deepEqual(Object.keys(classify([named(1, "com.example.ghostty")], undefined, true, false)), []);
for (const enabled of ["true", "false", 1, 0, null, undefined, {}, []])
    assert.deepEqual(Object.keys(classify([named(1, "com.example.ghostty")], store([definition({enabled})]))), []);

result = classify([named(2, "app", "Exact")], store([definition({appId: "", title: "Exact"})]));
assert.equal(result["2"].command, "toggle_named_scratchpad,none,^Exact$,ghostty --class=com.example.ghostty");
assert.ok(classify([named(3, "app", "Title")], store([definition({appId: "app", title: "Title"})]))["3"]);
assert.deepEqual(Object.keys(classify([named(3, "application", "Title")], store([definition({appId: "app", title: "Title"})]))), []);
assert.deepEqual(Object.keys(classify([named(3, "app", "A Title")], store([definition({appId: "app", title: "Title"})]))), []);

// Runtime remains defensive even if persistence is manually corrupted.
assert.deepEqual(Object.keys(classify([named(4, "same")], store([
    definition(), definition({id: "other", displayName: "Other"})
]))), []);
assert.deepEqual(Object.keys(classify([
    named(5, "com.example.ghostty"), named(6, "com.example.ghostty")
])), []);

const literal = definitions.canonicalDefinition(definition({appId: "a.b+[x]", title: "T(1)"}));
assert.equal(runtime.dispatcherCommand(literal),
    "toggle_named_scratchpad,^a\\.b\\+\\[x\\]$,^T\\(1\\)$,ghostty --class=com.example.ghostty");

const daemon = fs.readFileSync("ScratchpadDaemon.qml", "utf8");
const widget = fs.readFileSync("ScratchpadWidget.qml", "utf8");
const card = fs.readFileSync("ScratchpadCard.qml", "utf8");
assert.ok(daemon.includes("NamedRuntime.classify"));
assert.ok(daemon.includes("MangoService.dispatch(association.command"));
assert.ok(daemon.includes('MangoService.dispatch("focusid client," + id'));
assert.ok(!runtime.dispatcherCommand(literal).includes("focusid"));
assert.ok(!daemon.includes('Proc.runCommand(null, [association'));
assert.ok(!daemon.includes('"sh", "-c"') && !daemon.includes('"bash", "-c"'));
assert.ok(widget.includes("picker.activateRequested(selectedClientId)"));
assert.ok(card.includes("root.activated(root.client.clientId)"));
assert.ok(card.includes("Named · Managed") && card.includes("Named · External"));
assert.ok(daemon.includes("namedManagerAppliedHash"));
assert.ok(daemon.includes("watchChanges: true"));
assert.ok(daemon.includes("function onPluginDataChanged"));
assert.ok(daemon.includes("root.rebuildModel();"));

console.log("named-runtime-contract: PASS");
