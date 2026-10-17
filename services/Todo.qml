pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * Simple to-do list manager.
 * Each item is an object with "content" and "done" properties.
 */
Singleton {
    id: root
    property var filePath: Directories.todoPath
    property var list: []
    // A file that did not parse still holds the items: it is never written over, or the first
    // task added after a crash mid-write would replace the whole list with itself.
    property bool broken: false

    function save() {
        if (root.broken) {
            console.log("[To Do] Not saving: " + root.filePath + " did not parse")
            return
        }
        todoFileView.setText(JSON.stringify(root.list))
    }
    
    function addItem(item) {
        list.push(item)
        // Reassign to trigger onListChanged
        root.list = list.slice(0)
        save()
    }

    function addTask(desc) {
        const item = {
            "content": desc,
            "done": false,
        }
        addItem(item)
    }

    function markDone(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = true
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            save()
        }
    }

    function markUnfinished(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = false
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            save()
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < list.length) {
            list.splice(index, 1)
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            save()
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const fileContents = todoFileView.text()
            try {
                const parsed = JSON.parse(fileContents)
                if (Array.isArray(parsed)) {
                    root.list = parsed
                    root.broken = false
                    console.log("[To Do] File loaded")
                } else {
                    root.broken = true
                    console.log("[To Do] The file is not a list; keeping the items in memory")
                }
            } catch (e) {
                root.broken = true
                console.log("[To Do] Cannot read the file, keeping the items in memory: " + e)
            }
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[To Do] File not found, creating new file.")
                root.list = []
                todoFileView.setText(JSON.stringify(root.list))
            } else {
                console.log("[To Do] Error loading file: " + error)
            }
        }
    }
}

