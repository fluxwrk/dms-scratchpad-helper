.pragma library

function parseFocusedClient(output) {
    let client;
    try {
        client = JSON.parse(String(output || "").trim());
    } catch (e) {
        return null;
    }
    const id = Number(client?.id);
    if (!Number.isInteger(id) || id <= 0 || client?.error)
        return null;
    client.id = id;
    return client;
}

function validCaptureGeometry(client) {
    return Number.isFinite(Number(client?.x)) && Number.isFinite(Number(client?.y)) && Number.isFinite(Number(client?.width)) && Number.isFinite(Number(client?.height)) && Number(client.width) > 0 && Number(client.height) > 0;
}

function grimGeometry(client) {
    if (!validCaptureGeometry(client))
        return "";
    return Math.trunc(Number(client.x)) + "," + Math.trunc(Number(client.y)) + " " + Math.trunc(Number(client.width)) + "x" + Math.trunc(Number(client.height));
}

function previewScale(clientWidth, targetWidth) {
    const width = Number(clientWidth);
    const target = Number(targetWidth);
    if (!Number.isFinite(width) || !Number.isFinite(target) || width <= 0 || target <= 0)
        return 0;
    return Math.min(1, target / width);
}
