pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import Quickshell

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    // Deduped list to fix double icons
    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .filter((app, index, self) => 
            index === self.findIndex((t) => (
                t.id === app.id
            ))
    )
    
    // Search more than the bare Name. A terminal is called "Foot" or "kitty"; the word
    // "Terminal" only ever appears in GenericName, so typing "terminal" matched nothing.
    // Keywords and Comment carry the same kind of intent ("shell", "commandline").
    //
    // Three separate targets, not one joined string. Joined, fuzzysort scores the densest
    // subsequence anywhere in the blob and cannot tell a Name hit from a Comment hit, so a
    // tight accidental hit in a short Comment outranked the exact word sitting in Name.
    readonly property var preppedApps: list.map(a => ({
        name: Fuzzy.prepare(a.name),
        intent: Fuzzy.prepare(`${a.genericName ?? ""} ${(a.keywords ?? []).join(" ")}`),
        comment: Fuzzy.prepare(a.comment ?? ""),
        entry: a
    }))

    readonly property var preppedIcons: list.map(a => ({
        name: Fuzzy.prepare(`${a.icon} `),
        entry: a
    }))

    function fuzzyQuery(search: string): var { // Idk why list<DesktopEntry> doesn't work
        if (root.sloppySearch) {
            const results = list.map(obj => ({
                entry: obj,
                score: Levendist.computeScore(`${obj.name} ${obj.genericName ?? ""} ${(obj.keywords ?? []).join(" ")}`.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        const needle = (search ?? "").trim().toLowerCase();
        if (needle.length === 0)
            return root.list;

        // A Name hit beats the intent words, which beat the Comment; a Name that literally
        // starts with what was typed wins outright, which is what stops one more character
        // from dropping the app you just named out of the list. Equal scores fall to the
        // shorter name so the order cannot shuffle between keystrokes.
        return Fuzzy.go(needle, preppedApps, {
            keys: ["name", "intent", "comment"],
            scoreFn: result => {
                const nameScore = result[0].score;
                if (result.obj.entry.name.toLowerCase().startsWith(needle))
                    return 1 + nameScore;
                return Math.max(nameScore, 0.6 * result[1].score, 0.3 * result[2].score);
            }
        }).sort((a, b) => (b.score - a.score) || (a.obj.entry.name.length - b.obj.entry.name.length) || a.obj.entry.name.localeCompare(b.obj.entry.name)).map(r => {
            return r.obj.entry
        });
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getKebabNormalizedAppName(str) {
        return str.toLowerCase().replace(/\s+/g, "-");
    }

    function getUndescoreToKebabAppName(str) {
        return str.toLowerCase().replace(/_/g, "-");
    }

    // A miss costs five icon-theme lookups and two full fuzzy passes over every desktop
    // entry, and PaletteWindows re-resolves every open window on each Hyprland event. The
    // desktop entry list is the only input that can change, so the cache dies with it.
    property var iconCache: ({})
    onListChanged: root.iconCache = ({})

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";
        const cached = root.iconCache[str];
        if (cached !== undefined) return cached;
        // Written in place on purpose: reassigning iconCache here would make every caller's
        // binding depend on a property its own call had just changed.
        const icon = root.resolveIcon(str);
        root.iconCache[str] = icon;
        return icon;
    }

    function resolveIcon(str) {
        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.byId(str);
        if (entry) return entry.icon;

        // The window class an entry declares (StartupWMClass), which is not always its id: the
        // desktop's own apps report `praxis` and `graphis` and live in claude-app.desktop and
        // code.desktop.
        const declared = root.list.find(a => (a.startupClass ?? "").length > 0
            && a.startupClass.toLowerCase() === str.toLowerCase());
        if (declared) return declared.icon;

        // Normal substitutions
        if (substitutions[str]) return substitutions[str];
        if (substitutions[str.toLowerCase()]) return substitutions[str.toLowerCase()];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        // Icon exists -> return as is
        if (iconExists(str)) return str;


        // Simple guesses
        const lowercased = str.toLowerCase();
        if (iconExists(lowercased)) return lowercased;

        const reverseDomainNameAppName = getReverseDomainNameAppName(str);
        if (iconExists(reverseDomainNameAppName)) return reverseDomainNameAppName;

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return lowercasedDomainNameAppName;

        const kebabNormalizedGuess = getKebabNormalizedAppName(str);
        if (iconExists(kebabNormalizedGuess)) return kebabNormalizedGuess;

        const undescoreToKebabGuess = getUndescoreToKebabAppName(str);
        if (iconExists(undescoreToKebabGuess)) return undescoreToKebabGuess;

        // Search in desktop entries
        const iconSearchResults = Fuzzy.go(str, preppedIcons, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
        if (iconSearchResults.length > 0) {
            const guess = iconSearchResults[0].icon
            if (iconExists(guess)) return guess;
        }

        const nameSearchResults = root.fuzzyQuery(str);
        if (nameSearchResults.length > 0) {
            const guess = nameSearchResults[0].icon
            if (iconExists(guess)) return guess;
        }

        // Quickshell's desktop entry lookup
        const heuristicEntry = DesktopEntries.heuristicLookup(str);
        if (heuristicEntry) return heuristicEntry.icon;

        // Give up
        return "application-x-executable";
    }
}
