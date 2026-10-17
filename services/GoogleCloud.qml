pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common.utils

Singleton {
    id: root

    property var keyContent: ({})
    property string keyProjectId: keyContent?.project_id
    property bool keyError: false
    property bool keyReady: false
    property string token: ""
    property date tokenExpiry
    property bool tokenError: false
    property bool tokenReady: false
    readonly property string projectId: keyProjectId

    readonly property bool loaded: keyReady && tokenReady

    readonly property string tokenForKeyScriptPath: Quickshell.shellPath("services/gCloud/token-from-key-venv.sh")

    function load() {
        // Init load will be handled by Component.onCompleted
        if (!tokenReady) return;
        // We just reload if key expired
        if (new Date() >= root.tokenExpiry) {
            root.tokenReady = false;
            root.keyReady = false;
            loadKeyIfPossible();
        }
    }

    function unready() {
        root.keyReady = false;
        root.tokenReady = false;
        root.keyError = false;
        root.tokenError = false;
    }

    function setKeyJson(str: string): bool {
        try {
            var keyData = JSON.parse(str)
            root.unready();
            KeyringStorage.setNestedField(["googleCloud", "serviceAccountKey"], keyData);
            return true;
        } catch(e) {
            return false;
        }
    }

    function getToken() {
        if (root.keyError) {
            root.tokenError = true;
            root.tokenReady = true;
            return;
        }
        tokenProc.runSequence([(() => { // prep token fetcher
                // The key is handed over in the environment and read from there by the helper:
                // as an argument it became an argv element of both bash and python, and
                // /proc/<pid>/cmdline is world readable.
                tokenProc.environment = ({
                    "SERVICE_KEY_CONTENT": JSON.stringify(root.keyContent)
                });
                tokenProc.command = ["bash", root.tokenForKeyScriptPath];
            }), //
            [], // run token fetcher
            ((out) => {
                try {
                    const data = JSON.parse(out)
                    root.token = data.token
                    // Js wants millis instead of seconds
                    root.tokenExpiry = new Date(data.expiry * 1000) 
                    root.tokenError = false;
                } catch(e) {
                    root.tokenError = true;
                    print("[GoogleCloud] Failed to parse token response: " + e + "\n" + out)
                }
                root.tokenReady = true;
            }
            )]);
    }

    function loadKeyIfPossible() {
        if (KeyringStorage.loaded) {
            root.keyContent = KeyringStorage.keyringData?.googleCloud?.serviceAccountKey;
            if (!root.keyContent?.project_id) {
                root.keyError = true;
            } else {
                // keyProjectId is a binding on keyContent; assigning it here broke that binding.
                root.keyError = false;
            }
            root.keyReady = true;
            root.getToken();
        } else {
            KeyringStorage.fetchKeyringData();
        }
    }

    Component.onCompleted: {
        loadKeyIfPossible();
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            root.loadKeyIfPossible();
        }
        function onDataChanged() {
            // Every unrelated keyring write used to refetch a token; only our own key matters.
            const stored = KeyringStorage.keyringData?.googleCloud?.serviceAccountKey;
            if (JSON.stringify(stored ?? null) === JSON.stringify(root.keyContent ?? null)) return;
            root.loadKeyIfPossible();
        }
    }

    // The token lasts an hour, and load() only noticed it had expired while a request was
    // already going out with the dead one. Renew five minutes ahead instead.
    readonly property int renewInMs: {
        const expiry = root.tokenExpiry.getTime();
        if (isNaN(expiry))
            return 60000;
        return Math.max(30000, expiry - Date.now() - 5 * 60 * 1000);
    }

    Timer {
        interval: root.renewInMs
        running: root.tokenReady && !root.tokenError
        repeat: false
        onTriggered: {
            root.tokenReady = false;
            root.keyReady = false;
            root.loadKeyIfPossible();
        }
    }

    MultiTurnProcess {
        id: tokenProc
    }
}
