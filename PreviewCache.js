.pragma library

function normalizeClientId(clientId) {
    const value = Number(clientId);
    if (!Number.isInteger(value) || value <= 0)
        return "";
    return String(value);
}

function hex32(value) {
    return (Number(value) >>> 0).toString(16).padStart(8, "0");
}

function instanceDirectoryName(instanceIdentity) {
    const identity = typeof instanceIdentity === "string" ? instanceIdentity.trim() : "";
    if (!identity)
        return "";
    let first = 2166136261;
    let second = 2246822507;
    for (let i = 0; i < identity.length; ++i) {
        const code = identity.charCodeAt(i);
        first = Math.imul(first ^ code, 16777619) >>> 0;
        second = Math.imul(second ^ code, 3266489917) >>> 0;
    }
    return "instance-" + hex32(first) + hex32(second);
}

function isInstanceDirectoryName(directoryName) {
    return /^instance-[0-9a-f]{16}$/.test(String(directoryName || ""));
}

function isCurrentInstanceDirectory(directoryName, instanceIdentity) {
    const current = instanceDirectoryName(instanceIdentity);
    return !!current && directoryName === current;
}

function instanceCacheDir(cacheRoot, instanceIdentity) {
    const directoryName = instanceDirectoryName(instanceIdentity);
    if (!cacheRoot || !directoryName)
        return "";
    return String(cacheRoot).replace(/\/+$/, "") + "/" + directoryName;
}

function previewPath(cacheRoot, instanceIdentity, clientId) {
    return filePathForClient(instanceCacheDir(cacheRoot, instanceIdentity), clientId);
}

function fileNameForClient(clientId) {
    const id = normalizeClientId(clientId);
    return id ? "client-" + id + ".png" : "";
}

function clientIdFromFileName(fileName) {
    const match = /^client-([1-9][0-9]*)\.png$/.exec(String(fileName || ""));
    return match ? match[1] : "";
}

function filePathForClient(cacheDir, clientId) {
    const fileName = fileNameForClient(clientId);
    if (!fileName || !cacheDir)
        return "";
    return String(cacheDir).replace(/\/+$/, "") + "/" + fileName;
}

function temporaryFileNameForClient(clientId) {
    const id = normalizeClientId(clientId);
    return id ? "capture-" + id + ".tmp.png" : "";
}

function isTemporaryFileName(fileName) {
    return /^capture-[1-9][0-9]*\.tmp\.png$/.test(String(fileName || ""));
}

function captureAllowed(enabled, grimAvailable, geometryValid) {
    return enabled === true && grimAvailable === true && geometryValid === true;
}

function withoutClientPreview(entries, clientId) {
    const id = normalizeClientId(clientId);
    const result = Object.assign({}, entries || {});
    if (id)
        delete result[id];
    return result;
}

function activeClientIds(clients) {
    const ids = {};
    if (!Array.isArray(clients))
        return ids;
    for (const client of clients) {
        const id = normalizeClientId(client?.id);
        if (id)
            ids[id] = true;
    }
    return ids;
}

function staleFileNames(fileNames, clients) {
    const active = activeClientIds(clients);
    const stale = [];
    for (const fileName of fileNames || []) {
        const id = clientIdFromFileName(fileName);
        if (id && !active[id])
            stale.push(fileName);
    }
    return stale;
}
