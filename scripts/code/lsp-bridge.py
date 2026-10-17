#!/usr/bin/env python3
"""Graphis's way to a language server.

The server speaks the Language Server Protocol's framing (a Content-Length header, then the JSON); Graphis reads
one JSON message per line (Quickshell's line splitter). This sits between: lines in become framed requests, framed
messages out become lines. What the server asks of the editor is answered here, so a server never waits on
Graphis for it: settings (none - the server's own defaults), progress tokens and registrations (accepted).

    lsp-bridge.py <server> [args...]      stdin: one message per line    stdout: one message per line
A line {"bridge": "exit"} on stdout means the server has gone.
"""
import json
import os
import subprocess
import sys
import threading


def main():
    try:
        server = subprocess.Popen(sys.argv[1:], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, cwd=os.getcwd())
    except OSError as e:
        print(json.dumps({"bridge": "exit", "error": str(e)}), flush=True)
        return
    out_lock = threading.Lock()

    def emit(msg):
        with out_lock:
            sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
            sys.stdout.flush()

    send_lock = threading.Lock()

    def send(msg):
        msg.setdefault("jsonrpc", "2.0")
        data = json.dumps(msg, separators=(",", ":")).encode()
        with send_lock:
            server.stdin.write(b"Content-Length: %d\r\n\r\n" % len(data) + data)
            server.stdin.flush()

    def answer(msg):
        method = msg.get("method", "")
        if method == "workspace/configuration":
            result = [None for _ in msg.get("params", {}).get("items", [])]
        else:   # window/workDoneProgress/create, client/registerCapability, workspace/workspaceFolders ...
            result = None
        send({"id": msg["id"], "result": result})

    def read_server():
        f = server.stdout
        while True:
            length = 0
            while True:
                line = f.readline()
                if not line:
                    emit({"bridge": "exit"})
                    os._exit(0)
                line = line.decode("ascii", "replace").strip()
                if not line:
                    break
                key, _, value = line.partition(":")
                if key.strip().lower() == "content-length":
                    length = int(value.strip())
            body = f.read(length)
            try:
                msg = json.loads(body)
            except ValueError:
                continue
            if "method" in msg and "id" in msg:
                answer(msg)
            else:
                emit(msg)

    threading.Thread(target=read_server, daemon=True).start()
    try:
        for line in sys.stdin:
            line = line.strip()
            if line:
                send(json.loads(line))
    except (BrokenPipeError, ValueError):
        pass
    server.terminate()


if __name__ == "__main__":
    main()
