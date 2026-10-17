pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars.
 *
 * The desktop's one dismissal rule: a surface that opens on a CLICK or a KEY enrols here as
 * dismissable while it is open and closes itself in onDismissed. That is what makes "click away
 * to close" one behaviour rather than one per surface, and it is also what keeps a surface from
 * losing its first click to whichever panel already holds the grab.
 *
 * Surfaces that open on HOVER stay out: they close when the pointer leaves (the notch, the
 * notification centre). The grab is input-exclusive, so a hover-opened surface in it would hold
 * the seat over a window the pointer only crossed. Escape is the notch's compositor shortcut,
 * IslandController.collapseExpansion, which any surface can listen to.
 **/
 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized" + (WM.compositor !== "hyprland" ? " (inactive, non-Hyprland compositor)" : ""));
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent.push(window);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent.splice(index, 1);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable.push(window);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable.splice(index, 1);
        }
    }

    function hasActive(element) {
        return element?.activeFocus || Array.from(
            element?.children ?? []
        ).some(
            (child) => hasActive(child)
        );
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.dismissable.every(w => !w?.focusable) || root.dismissable.some(w => root.hasActive(w?.contentItem)) ? [...root.dismissable, ...root.persistent] : [...root.dismissable]
        active: WM.compositor === "hyprland" && root.dismissable.length > 0
        onCleared: () => {
            root.dismiss();
        }
    }
}