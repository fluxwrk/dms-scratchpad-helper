.pragma library

var SCHEMA_VERSION = 1;
var MAX_ID_BYTES = 80;
var MAX_NAME_BYTES = 120;
var MAX_IDENTITY_BYTES = 120;
var MAX_COMMAND_BYTES = 220;
var MAX_RULE_VALUE_BYTES = 240;
var MAX_LINE_BYTES = 480;

function utf8Length(value) {
    if (hasInvalidUnicode(String(value)))
        return Infinity;
    return unescape(encodeURIComponent(String(value))).length;
}

function hasInvalidUnicode(value) {
    for (let i = 0; i < value.length; ++i) {
        const code = value.charCodeAt(i);
        if (code >= 0xd800 && code <= 0xdbff) {
            if (i + 1 >= value.length) return true;
            const next = value.charCodeAt(++i);
            if (next < 0xdc00 || next > 0xdfff) return true;
        } else if (code >= 0xdc00 && code <= 0xdfff) {
            return true;
        }
    }
    return false;
}

function trim(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

function hasUnsafeControl(value) {
    return /[\u0000-\u001f\u007f-\u009f]/.test(value);
}

function hasMangoDelimiter(value) {
    return /[,\r\n\u0000]/.test(value);
}

function escapePcreLiteral(value) {
    return String(value).replace(/[\\.^$|?*+()\[\]{}-]/g, "\\$&");
}

function exactPattern(value) {
    return "^" + escapePcreLiteral(value) + "$";
}

function canonicalDefinition(raw) {
    raw = raw || {};
    const appId = trim(raw.appId);
    const title = trim(raw.title);
    return {
        "schemaVersion": SCHEMA_VERSION,
        "id": trim(raw.id),
        "displayName": trim(raw.displayName),
        "appId": appId,
        "title": title,
        "launchCommand": trim(raw.launchCommand),
        "enabled": raw.enabled !== false,
        "creationOrder": Number.isSafeInteger(raw.creationOrder) && raw.creationOrder >= 0 ? raw.creationOrder : 0,
        "canonicalKey": JSON.stringify([appId, title]),
        "appIdPattern": appId ? exactPattern(appId) : "",
        "titlePattern": title ? exactPattern(title) : ""
    };
}

function addError(errors, id, field, code, message) {
    errors.push({"id": id, "field": field, "code": code, "message": message});
}

function validateField(definition, field, value, maxBytes, errors) {
    if (hasInvalidUnicode(value))
        addError(errors, definition.id, field, "unicode", "Malformed Unicode is not allowed.");
    else if (hasMangoDelimiter(value))
        addError(errors, definition.id, field, "delimiter", "Commas and line breaks are not supported by Mango fields.");
    else if (hasUnsafeControl(value))
        addError(errors, definition.id, field, "control", "Control characters are not allowed.");
    if (utf8Length(value) > maxBytes)
        addError(errors, definition.id, field, "too-long", "The value is too long for Mango's parser.");
}

function identitiesOverlap(a, b) {
    if (a.appId && b.appId && a.appId !== b.appId)
        return false;
    if (a.title && b.title && a.title !== b.title)
        return false;
    return true;
}

function ruleLine(definition) {
    let fields = ["isnamedscratchpad:1"];
    if (definition.appIdPattern)
        fields.push("appid:" + definition.appIdPattern);
    if (definition.titlePattern)
        fields.push("title:" + definition.titlePattern);
    return "windowrule=" + fields.join(",");
}

function validateDefinitions(rawDefinitions) {
    const source = Array.isArray(rawDefinitions) ? rawDefinitions : [];
    const definitions = source.map(canonicalDefinition);
    let errors = [];
    let warnings = [];
    let ids = {};
    let keys = {};

    definitions.forEach(function(definition) {
        if (!definition.id)
            addError(errors, definition.id, "id", "required", "A stable ID is required.");
        else if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(definition.id))
            addError(errors, definition.id, "id", "format", "Stable IDs may contain letters, numbers, dots, underscores, and hyphens.");
        validateField(definition, "id", definition.id, MAX_ID_BYTES, errors);

        if (!definition.displayName)
            addError(errors, definition.id, "displayName", "required", "Display name is required.");
        validateField(definition, "displayName", definition.displayName, MAX_NAME_BYTES, errors);

        if (!definition.appId && !definition.title)
            addError(errors, definition.id, "identity", "required", "Application ID or window title is required.");
        ["appId", "title"].forEach(function(field) {
            const value = definition[field];
            if (!value)
                return;
            validateField(definition, field, value, MAX_IDENTITY_BYTES, errors);
            if (value.substring(0, 4).toLowerCase() === "none")
                addError(errors, definition.id, field, "none-sentinel", "Values beginning with 'none' conflict with Mango's reserved sentinel.");
        });

        if (!definition.launchCommand)
            addError(errors, definition.id, "launchCommand", "required", "A Mango launch command is required.");
        validateField(definition, "launchCommand", definition.launchCommand, MAX_COMMAND_BYTES, errors);

        if (ids[definition.id])
            addError(errors, definition.id, "id", "duplicate", "Stable IDs must be unique.");
        ids[definition.id] = true;
        if (keys[definition.canonicalKey])
            addError(errors, definition.id, "identity", "duplicate", "Managed identities must be unique.");
        keys[definition.canonicalKey] = true;

        const line = ruleLine(definition);
        const value = line.substring("windowrule=".length);
        if (utf8Length(value) > MAX_RULE_VALUE_BYTES)
            addError(errors, definition.id, "identity", "rule-value-too-long", "The generated Mango rule value exceeds the safe parser limit.");
        if (utf8Length(line) > MAX_LINE_BYTES)
            addError(errors, definition.id, "identity", "line-too-long", "The generated Mango rule line exceeds the safe parser limit.");

        if (!definition.appId && definition.title)
            warnings.push({"id": definition.id, "code": "title-only", "message": "Title-only identities may change while an application runs."});
    });

    for (let i = 0; i < definitions.length; ++i) {
        for (let j = i + 1; j < definitions.length; ++j) {
            if (identitiesOverlap(definitions[i], definitions[j]) && definitions[i].canonicalKey !== definitions[j].canonicalKey)
                addError(errors, definitions[j].id, "identity", "overlap", "Managed exact identities overlap and could target the same window.");
            if (definitions[i].launchCommand && definitions[i].launchCommand === definitions[j].launchCommand && definitions[i].canonicalKey !== definitions[j].canonicalKey)
                warnings.push({"id": definitions[j].id, "code": "duplicate-command", "message": "Another definition uses the same launch command."});
        }
    }

    return {"valid": errors.length === 0, "definitions": definitions, "errors": errors, "warnings": warnings};
}

function safeComment(value) {
    return trim(value).replace(/[\r\n\u0000-\u001f\u007f-\u009f]/g, " ");
}

function compareDefinitions(a, b) {
    if (a.creationOrder !== b.creationOrder)
        return a.creationOrder - b.creationOrder;
    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0);
}

function serializeDefinitions(rawDefinitions) {
    const result = validateDefinitions(rawDefinitions);
    if (!result.valid)
        return {"valid": false, "content": "", "errors": result.errors, "warnings": result.warnings, "definitions": result.definitions};

    const enabled = result.definitions.filter(function(definition) { return definition.enabled; }).sort(compareDefinitions);
    let lines = [
        "# Generated by Scratchpad Helper. Do not edit by hand.",
        "# Schema: " + SCHEMA_VERSION,
        "# Manager state is stored by the plugin; this file contains only Mango rules.",
        ""
    ];
    enabled.forEach(function(definition, index) {
        if (index > 0)
            lines.push("");
        lines.push("# managed-id: " + definition.id);
        lines.push("# name: " + safeComment(definition.displayName));
        lines.push(ruleLine(definition));
    });
    return {"valid": true, "content": lines.join("\n") + "\n", "errors": [], "warnings": result.warnings, "definitions": result.definitions};
}

// Small in-process SHA-256 implementation. Hashes UTF-8 bytes and never invokes a process.
function contentHash(input) {
    const text = unescape(encodeURIComponent(String(input)));
    const rightRotate = function(value, amount) { return (value >>> amount) | (value << (32 - amount)); };
    let words = [];
    let bitLength = text.length * 8;
    for (let i = 0; i < text.length; ++i)
        words[i >> 2] = (words[i >> 2] || 0) | (text.charCodeAt(i) << (24 - (i % 4) * 8));
    words[bitLength >> 5] = (words[bitLength >> 5] || 0) | (0x80 << (24 - bitLength % 32));
    words[(((bitLength + 64) >> 9) << 4) + 15] = bitLength;
    let h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    let k = [];
    let prime = 2;
    while (k.length < 64) {
        let isPrime = true;
        for (let divisor = 2; divisor * divisor <= prime; ++divisor)
            if (prime % divisor === 0) { isPrime = false; break; }
        if (isPrime) {
            if (k.length < 8)
                h[k.length] = (Math.pow(prime, 0.5) % 1 * 0x100000000) | 0;
            k.push((Math.pow(prime, 1 / 3) % 1 * 0x100000000) | 0);
        }
        ++prime;
    }
    for (let offset = 0; offset < words.length; offset += 16) {
        let w = [];
        for (let i = 0; i < 64; ++i) {
            if (i < 16)
                w[i] = words[offset + i] | 0;
            else {
                const x = w[i - 15], y = w[i - 2];
                const s0 = rightRotate(x, 7) ^ rightRotate(x, 18) ^ (x >>> 3);
                const s1 = rightRotate(y, 17) ^ rightRotate(y, 19) ^ (y >>> 10);
                w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
            }
        }
        let a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (let i = 0; i < 64; ++i) {
            const s1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25);
            const ch = (e & f) ^ (~e & g);
            const t1 = (hh + s1 + ch + k[i] + w[i]) | 0;
            const s0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22);
            const maj = (a & b) ^ (a & c) ^ (b & c);
            const t2 = (s0 + maj) | 0;
            hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
        }
        h = [(h[0] + a) | 0, (h[1] + b) | 0, (h[2] + c) | 0, (h[3] + d) | 0,
             (h[4] + e) | 0, (h[5] + f) | 0, (h[6] + g) | 0, (h[7] + hh) | 0];
    }
    return h.map(function(value) { return (value >>> 0).toString(16).padStart(8, "0"); }).join("");
}

function ownershipState(existingContent, knownHash) {
    if (existingContent === null || existingContent === undefined)
        return {"state": "absent", "hash": ""};
    const actualHash = contentHash(existingContent);
    if (knownHash && actualHash === knownHash)
        return {"state": "owned", "hash": actualHash};
    return {"state": "conflict", "hash": actualHash};
}

function escapeRegex(value) {
    return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function detectsExpectedInclude(content, absoluteTargetPath) {
    const tilde = /^\s*source-optional\s*=\s*~\/\.config\/mango\/scratchpad-helper\.conf\s*$/;
    const absolute = new RegExp("^\\s*source-optional\\s*=\\s*" + escapeRegex(absoluteTargetPath) + "\\s*$");
    return String(content || "").split(/\r?\n/).some(function(line) {
        const uncommented = line.replace(/\s+#.*$/, "");
        return tilde.test(uncommented) || absolute.test(uncommented);
    });
}

function defaultStore() {
    return {"schemaVersion": SCHEMA_VERSION, "definitions": []};
}
