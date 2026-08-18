.pragma library

function normalizeHomePath(homePath) {
    const path = String(homePath || "").replace(/\/+$/, "");
    return path;
}

function configDirectory(homePath) {
    const home = normalizeHomePath(homePath);
    return home ? home + "/.config/mango" : "";
}

function helperConfigPath(homePath) {
    const directory = configDirectory(homePath);
    return directory ? directory + "/scratchpad-helper.conf" : "";
}

function mainConfigPath(homePath) {
    const directory = configDirectory(homePath);
    return directory ? directory + "/config.conf" : "";
}

function helperIncludeLine() {
    return "source-optional=~/.config/mango/scratchpad-helper.conf";
}
