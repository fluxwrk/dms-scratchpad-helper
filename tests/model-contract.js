const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("ScratchpadModel.js", "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.deepEqual(Array.from(context.normalizeClients([])), []);
assert.deepEqual(Array.from(context.normalizeClients(null)), []);

const result = context.normalizeClients([
    { id: 1, appid: "ghostty", title: "fish", is_scratchpad: true },
    { id: 2, appid: "firefox", title: "Docs", is_namedscratchpad: true },
    { id: 3, is_scratchpad: false, is_namedscratchpad: false },
    { id: 4, is_scratchpad: "true" },
    null
]);

assert.equal(result.length, 2);
assert.equal(result[0].type, "standard");
assert.equal(result[1].type, "named");
assert.equal(result[0].foreignToplevelId, "");
assert.equal(result[0].isVisible, false);
assert.equal(context.normalizeClient({ is_scratchpad: true }).appId, "Unknown application");
assert.equal(context.normalizeClient({ is_namedscratchpad: true }).title, "Untitled");

const withPreview = context.normalizeClients([
    { id: 11, appid: "ghostty", is_scratchpad: true },
    { id: 12, appid: "ghostty", is_scratchpad: true },
    { id: 13, appid: "firefox", is_scratchpad: true }
], {
    "11": { path: "/cache/client-11.png", url: "file:///cache/client-11.png?v=1" },
    "12": { path: "/cache/client-12.png", url: "file:///cache/client-12.png?v=2" }
});

assert.equal(withPreview[0].hasPreview, true);
assert.equal(withPreview[0].previewPath, "/cache/client-11.png");
assert.equal(withPreview[1].previewPath, "/cache/client-12.png");
assert.equal(withPreview[2].hasPreview, false);
assert.equal(withPreview[2].previewPath, "");

console.log("model-contract: PASS");
