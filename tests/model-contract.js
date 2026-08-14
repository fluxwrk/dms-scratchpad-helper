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
assert.equal(context.normalizeClient({ is_namedscratchpad: true }).title, "Untitled window");

console.log("model-contract: PASS");
