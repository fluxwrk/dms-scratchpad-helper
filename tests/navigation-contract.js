const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("ScratchpadNavigation.js", "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

const clients = [
    { clientId: 1, type: "standard" },
    { clientId: 2, type: "standard" },
    { clientId: 3, type: "standard" },
    { clientId: 4, type: "standard" },
    { clientId: 5, type: "named" },
    { clientId: 6, type: "standard" }
];

assert.equal(context.firstActionableId(clients), "1");
assert.equal(context.moveSelection(clients, 1, "right", 2), "2");
assert.equal(context.moveSelection(clients, 2, "left", 2), "1");
assert.equal(context.moveSelection(clients, 1, "down", 2), "3");
assert.equal(context.moveSelection(clients, 2, "down", 2), "4");
assert.equal(context.moveSelection(clients, 4, "down", 2), "6");
assert.equal(context.moveSelection(clients, 6, "up", 2), "4");
assert.equal(context.moveSelection(clients, 4, "right", 2), "4");

const namedFirst = [
    { clientId: 10, type: "named" },
    { clientId: 11, type: "standard" }
];
assert.equal(context.firstActionableId(namedFirst), "11");

const afterRemoval = context.reconcileSelection(clients.filter(client => client.clientId !== 3), 3, 2);
assert.equal(afterRemoval.clientId, "4");
assert.equal(afterRemoval.index, 2);

const namedOnly = context.reconcileSelection([{ clientId: 20, type: "named" }], 20, 0);
assert.equal(namedOnly.clientId, "");
assert.equal(namedOnly.index, -1);

console.log("navigation-contract: PASS");
