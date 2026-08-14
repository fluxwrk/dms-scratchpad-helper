const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("StashWorkflow.js", "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

const focused = context.parseFocusedClient(JSON.stringify({
    id: 17,
    x: -100,
    y: 41,
    width: 1918,
    height: 1158,
    is_visible: true
}));
assert.equal(focused.id, 17);
assert.equal(context.parseFocusedClient("not json"), null);
assert.equal(context.parseFocusedClient('{"error":"no focused client"}'), null);
assert.equal(context.parseFocusedClient('{"id":0}'), null);

assert.equal(context.validCaptureGeometry(focused), true);
assert.equal(context.validCaptureGeometry({ x: 0, y: 0, width: 0, height: 100 }), false);
assert.equal(context.validCaptureGeometry({ x: 0, y: 0, width: "bad", height: 100 }), false);
assert.equal(context.grimGeometry(focused), "-100,41 1918x1158");
assert.equal(context.grimGeometry({}), "");

assert.equal(context.previewScale(1918, 320), 320 / 1918);
assert.equal(context.previewScale(200, 320), 1);
assert.equal(context.previewScale(0, 320), 0);

console.log("stash-workflow-contract: PASS");
