// The words for an agent's steps: which kind a step is, how a line of them reads ("Ran 4 commands",
// "Read notes.txt"), its glyph, and how long something took ("2m 5s"). Used by ActivityGroup (a
// turn's steps) and AgentRow (an agent's newest step).

function kind(it) {
    if (it.kind === "thinking") return "think";
    switch (it.tool) {
    case "Agent": case "Task": return "agent";
    case "Bash": case "BashOutput": case "KillShell": case "KillBash": case "Monitor":
    case "shell": case "shell_command": case "exec_command": return "run";
    case "Edit": case "MultiEdit": case "Write": case "NotebookEdit": case "apply_patch": return "edit";
    case "Read": case "view_image": return "read";
    case "Grep": case "Glob": case "LS": case "ToolSearch": return "search";
    case "WebSearch": return "web";
    case "WebFetch": return "fetch";
    case "TaskCreate": case "TaskUpdate": case "TaskList": case "TaskGet": case "TodoWrite": case "update_plan": return "plan";
    }
    return "tool:" + (it.tool ?? "");
}

function base(p) { return String(p ?? "").replace(/\/+$/, "").split("/").pop(); }

function says(k, all) {
    const steps = [];
    for (let i = 0; i < all.length; i++) if (k === "think" || all[i].kind !== "thinking") steps.push(all[i]);
    const n = steps.length;
    switch (k) {
    case "think": return "Thought";
    case "run": {
        // checking on a background command is not running one
        const checks = steps.filter(s => ["BashOutput", "Monitor", "KillShell", "KillBash"].includes(s.tool)).length;
        const ran = n - checks;
        if (!ran) return checks === 1 ? "Checked a running command" : `Checked running commands ${checks} times`;
        return ran === 1 ? "Ran a command" : `Ran ${ran} commands`;
    }
    case "agent": return n === 1 ? "Started an agent" : `Started ${n} agents`;
    case "edit": {
        const paths = [];
        for (const st of steps) for (const f of st.files ?? []) if (!paths.includes(f.path)) paths.push(f.path);
        return paths.length === 1 ? `Edited ${base(paths[0])}` : `Edited ${paths.length || n} files`;
    }
    case "read": {
        const paths = [...new Set(steps.map(s => s.summary ?? ""))];
        return n === 1 || (paths.length === 1 && paths[0].length) ? `Read ${base(paths[0]) || "a file"}` : `Read ${n} files`;
    }
    case "search": return n === 1 ? "Searched" : `Searched ${n} times`;
    case "web": return n === 1 ? "Searched the web" : `Searched the web ${n} times`;
    case "fetch": return n === 1 ? "Read a web page" : `Read ${n} web pages`;
    case "plan": return "Updated the plan";
    }
    const name = k.substring(5);
    return n === 1 ? `Used ${name}` : `Used ${name} ${n} times`;
}

// The same line while its last step is still going: what it is doing now, not what it did ("Ran a
// command" read as done while the command ran, and while it waited for permission to run at all).
function doing(k, all) {
    const now = all[all.length - 1] ?? {};
    switch (k) {
    case "think": return "Thinking";
    case "run": return "Running a command";
    case "agent": return "Starting an agent";
    case "edit": {
        const f = (now.files ?? [])[0]?.path ?? now.summary ?? "";
        return base(f) ? `Editing ${base(f)}` : "Editing";
    }
    case "read": return base(now.summary) ? `Reading ${base(now.summary)}` : "Reading";
    case "search": return "Searching";
    case "web": return "Searching the web";
    case "fetch": return "Reading a web page";
    case "plan": return "Updating the plan";
    }
    return `Using ${k.substring(5)}`;
}

function glyph(k) {
    switch (k) {
    case "think": return "neurology";
    case "run": return "terminal";
    case "edit": return "edit_note";
    case "read": return "description";
    case "search": return "manage_search";
    case "web": case "fetch": return "language";
    case "plan": return "checklist";
    }
    return "widgets";
}

function span(ms) {
    const s = Math.max(0, Math.round(ms / 1000));
    return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor(s % 3600 / 60)}m`;
}
