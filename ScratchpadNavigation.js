.pragma library

function clientId(client) {
    if (client?.clientId === undefined || client?.clientId === null)
        return "";
    return String(client.clientId);
}

function isActionable(client) {
    return client?.actionable === true && clientId(client) !== "";
}

function firstActionableId(clients) {
    for (const client of clients || []) {
        if (isActionable(client))
            return clientId(client);
    }
    return "";
}

function indexOfClient(clients, selectedClientId) {
    const selected = String(selectedClientId ?? "");
    if (!selected)
        return -1;
    for (let i = 0; i < (clients || []).length; ++i) {
        if (clientId(clients[i]) === selected)
            return i;
    }
    return -1;
}

function moveSelection(clients, selectedClientId, direction, columns) {
    const model = Array.isArray(clients) ? clients : [];
    const columnCount = Math.max(1, Number(columns) || 1);
    const current = indexOfClient(model, selectedClientId);
    if (current < 0 || !isActionable(model[current]))
        return firstActionableId(model);

    let step = 0;
    let candidate = current;
    if (direction === "left" || direction === "right") {
        step = direction === "left" ? -1 : 1;
        const row = Math.floor(current / columnCount);
        candidate += step;
        while (candidate >= 0 && candidate < model.length && Math.floor(candidate / columnCount) === row) {
            if (isActionable(model[candidate]))
                return clientId(model[candidate]);
            candidate += step;
        }
    } else if (direction === "up" || direction === "down") {
        step = direction === "up" ? -columnCount : columnCount;
        candidate += step;
        while (candidate >= 0 && candidate < model.length) {
            if (isActionable(model[candidate]))
                return clientId(model[candidate]);
            candidate += step;
        }
    }
    return clientId(model[current]);
}

function reconcileSelection(clients, selectedClientId, previousIndex) {
    const model = Array.isArray(clients) ? clients : [];
    const current = indexOfClient(model, selectedClientId);
    if (current >= 0 && isActionable(model[current]))
        return { "clientId": clientId(model[current]), "index": current };

    const anchor = Number.isInteger(previousIndex) && previousIndex >= 0 ? previousIndex : 0;
    let nearestIndex = -1;
    let nearestDistance = Number.POSITIVE_INFINITY;
    for (let i = 0; i < model.length; ++i) {
        if (!isActionable(model[i]))
            continue;
        const distance = Math.abs(i - anchor);
        if (distance < nearestDistance) {
            nearestIndex = i;
            nearestDistance = distance;
        }
    }
    return nearestIndex >= 0 ? { "clientId": clientId(model[nearestIndex]), "index": nearestIndex } : { "clientId": "", "index": -1 };
}
