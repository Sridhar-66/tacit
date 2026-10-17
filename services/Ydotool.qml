pragma Singleton

import qs.modules.common
import Quickshell

Singleton {
    id: root
    property int shiftMode: 0 // 0: off, 1: on, 2: lock
    property list<int> shiftKeys: [42, 54] // Keycodes for Shift keys (left and right)
    property list<int> altKeys: [56, 100] // Keycodes for Alt keys (left and right) 
    property list<int> ctrlKeys: [29, 97] // Keycodes for Ctrl keys (left and right)

    function releaseAllKeys() {
        // From 1: keycode 0 is KEY_RESERVED, and the whole list goes to ydotool as one call, so a
        // single argument it refuses would lose all 248 releases and leave a modifier latched.
        const keycodes = Array.from({ length: 248 }, (_, i) => i + 1);
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            ...keycodes.map(keycode => `${keycode}:0`)
        ])
        root.shiftMode = 0; // Reset shift mode
    }

    function releaseShiftKeys() {
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            ...root.shiftKeys.map(keycode => `${keycode}:0`)
        ])
        root.shiftMode = 0; // Reset shift mode
    }

    function press(keycode) {
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            `${keycode}:1`
        ]);
    }

    function release(keycode) {
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            `${keycode}:0`
        ]);
    }
}
