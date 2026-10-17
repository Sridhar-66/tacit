pragma Singleton

import Quickshell

// The product's own name and release, in one place. Window titles, the About page and the
// keyring entry all have to agree on it, and it is deliberately NOT part of Config's
// JsonAdapter: none of this belongs in the user's config.json, where a stale copy would
// outlive the build that wrote it.
Singleton {
    readonly property string name: "Tacit"
    readonly property string version: "0.1.0"
    readonly property string nameAndVersion: `${Product.name} ${Product.version}`
}
