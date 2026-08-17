.pragma library

function concreteText(value) {
    return value === undefined || value === null ? "" : String(value);
}

function liveIdentityMatches(definition, client) {
    if (!definition || !client)
        return false;
    const appId = concreteText(client.appid);
    const title = concreteText(client.title);
    return (!definition.appId || appId === definition.appId) &&
        (!definition.title || title === definition.title);
}

function dispatcherCommand(definition) {
    if (!definition)
        return "";
    return "toggle_named_scratchpad," +
        (definition.appIdPattern || "none") + "," +
        (definition.titlePattern || "none") + "," +
        definition.launchCommand;
}

function classify(clients, rawStore, managerEnabled, configSynchronized, definitionsApi) {
    const source = Array.isArray(clients) ? clients : [];
    const associations = {};
    if (!managerEnabled || !configSynchronized || !definitionsApi)
        return associations;

    const loaded = definitionsApi.loadStore(rawStore);
    if (!loaded.valid)
        return associations;
    const validated = definitionsApi.validateDefinitions(loaded.store.definitions);
    if (!validated.valid)
        return associations;

    const definitions = validated.definitions.filter(function(definition) {
        return definition.enabled === true;
    });
    const namedClients = source.filter(function(client) {
        return client && client.is_namedscratchpad === true;
    });

    for (let clientIndex = 0; clientIndex < namedClients.length; ++clientIndex) {
        const client = namedClients[clientIndex];
        const matches = definitions.filter(function(definition) {
            return liveIdentityMatches(definition, client);
        });
        if (matches.length !== 1)
            continue;
        const definition = matches[0];
        const matchingClients = namedClients.filter(function(candidate) {
            return liveIdentityMatches(definition, candidate);
        });
        if (matchingClients.length !== 1)
            continue;
        associations[String(client.id)] = {
            "definitionId": definition.id,
            "displayName": definition.displayName,
            "command": dispatcherCommand(definition)
        };
    }
    return associations;
}
