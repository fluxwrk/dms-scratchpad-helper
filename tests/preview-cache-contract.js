const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("PreviewCache.js", "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.equal(context.normalizeClientId(7), "7");
assert.equal(context.normalizeClientId("8"), "8");
assert.equal(context.normalizeClientId(0), "");
assert.equal(context.normalizeClientId("not-an-id"), "");

const cacheRoot = "/tmp/scratchpad-helper/previews";
const firstInstance = "/run/user/1000/mango-ipc.100";
const secondInstance = "/run/user/1000/mango-ipc.200";
const firstInstanceDir = context.instanceCacheDir(cacheRoot, firstInstance);
const secondInstanceDir = context.instanceCacheDir(cacheRoot, secondInstance);
assert.notEqual(firstInstanceDir, secondInstanceDir);
assert.notEqual(context.previewPath(cacheRoot, firstInstance, 3), context.previewPath(cacheRoot, secondInstance, 3));
assert.equal(context.previewPath(cacheRoot, firstInstance, 3), context.filePathForClient(firstInstanceDir, 3));
assert.equal(context.instanceCacheDir(cacheRoot, firstInstance), firstInstanceDir);
assert.equal(context.isInstanceDirectoryName(firstInstanceDir.split("/").pop()), true);
assert.equal(context.isInstanceDirectoryName(secondInstanceDir.split("/").pop()), true);
assert.equal(context.isCurrentInstanceDirectory(firstInstanceDir.split("/").pop(), firstInstance), true);
assert.equal(context.isCurrentInstanceDirectory(firstInstanceDir.split("/").pop(), secondInstance), false);
assert.equal(context.instanceCacheDir(cacheRoot, ""), "");
const hostileInstanceDir = context.instanceCacheDir(cacheRoot, "../../outside\n/socket");
assert.equal(hostileInstanceDir.startsWith(cacheRoot + "/instance-"), true);
assert.equal(hostileInstanceDir.includes(".."), false);
assert.equal(context.isInstanceDirectoryName("../instance-deadbeefdeadbeef"), false);

assert.equal(context.fileNameForClient(42), "client-42.png");
assert.equal(context.filePathForClient("/tmp/cache/", 42), "/tmp/cache/client-42.png");
assert.equal(context.clientIdFromFileName("client-42.png"), "42");
assert.equal(context.clientIdFromFileName("../client-42.png"), "");
assert.equal(context.clientIdFromFileName("client-firefox.png"), "");
assert.equal(context.temporaryFileNameForClient(42), "capture-42.tmp.png");
assert.equal(context.isTemporaryFileName("capture-42.tmp.png"), true);
assert.equal(context.isTemporaryFileName("capture-42.png"), false);
assert.equal(context.captureAllowed(true, true, true), true);
assert.equal(context.captureAllowed(false, true, true), false);
assert.equal(context.captureAllowed(true, false, true), false);
assert.equal(context.captureAllowed(true, true, false), false);

const previews = {
    "41": { path: "/cache/client-41.png" },
    "42": { path: "/cache/client-42.png" }
};
const withoutFreshCapture = context.withoutClientPreview(previews, 41);
assert.equal(withoutFreshCapture["41"], undefined);
assert.equal(withoutFreshCapture["42"].path, "/cache/client-42.png");
assert.equal(previews["41"].path, "/cache/client-41.png");

const sameAppClients = [
    { id: 41, appid: "com.mitchellh.ghostty" },
    { id: 42, appid: "com.mitchellh.ghostty" }
];
assert.equal(context.fileNameForClient(sameAppClients[0].id), "client-41.png");
assert.equal(context.fileNameForClient(sameAppClients[1].id), "client-42.png");

const stale = context.staleFileNames(
    ["client-41.png", "client-42.png", "client-99.png", "unrelated.txt"],
    sameAppClients
);
assert.deepEqual(Array.from(stale), ["client-99.png"]);
assert.deepEqual(Object.keys(context.activeClientIds(null)), []);

console.log("preview-cache-contract: PASS");
