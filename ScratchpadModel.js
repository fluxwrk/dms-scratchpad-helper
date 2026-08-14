.pragma library

function valueOr(value, fallback) {
    return value === undefined || value === null ? fallback : value;
}

function textOr(value, fallback) {
    if (value === undefined || value === null)
        return fallback;
    const text = String(value).trim();
    return text.length > 0 ? text : fallback;
}

function normalizeClient(client) {
    if (!client || typeof client !== "object")
        return null;

    const standard = client.is_scratchpad === true;
    const named = client.is_namedscratchpad === true;
    if (!standard && !named)
        return null;

    return {
        "clientId": valueOr(client.id, ""),
        "pid": valueOr(client.pid, 0),
        "foreignToplevelId": textOr(client.foreign_toplevel_id, ""),
        "appId": textOr(client.appid, "Unknown application"),
        "title": textOr(client.title, "Untitled window"),
        "monitor": textOr(client.monitor, ""),
        "type": named ? "named" : "standard",
        "isVisible": client.is_visible === true,
        "isMinimized": client.is_minimized === true,
        "x": valueOr(client.x, 0),
        "y": valueOr(client.y, 0),
        "width": valueOr(client.width, 0),
        "height": valueOr(client.height, 0)
    };
}

function normalizeClients(clients) {
    if (!Array.isArray(clients))
        return [];

    const result = [];
    for (let i = 0; i < clients.length; ++i) {
        const normalized = normalizeClient(clients[i]);
        if (normalized)
            result.push(normalized);
    }
    return result;
}
