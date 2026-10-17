#!/usr/bin/env python3
"""passwd.py: changes your password for Settings (Your account > Password). Two lines on stdin, the password now and the
new one, so neither is ever in a command line. passwd reads passwords from a terminal only, so it runs in a
pseudo-terminal and is answered prompt by prompt. Prints one line: "changed", or why not in plain words; exits 0 only
when it changed. The keyring follows the new password where PAM's passwd has pam_gnome_keyring (tacit-install adds it)."""
import os, pty, re, select, signal, sys, time


def change(now, new):
    """passwd's exit code and everything it wrote"""
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["LC_ALL"] = "C"          # the messages matched below are passwd's English ones
        os.execvp("passwd", ["passwd"])
    answers, out, deadline = [now, new, new], "", time.time() + 30
    while time.time() < deadline:
        if not select.select([fd], [], [], 0.5)[0]:
            continue
        try:
            chunk = os.read(fd, 1024).decode(errors="replace")
        except OSError:                     # passwd has finished: its terminal is gone
            break
        if not chunk:
            break
        out += chunk
        # "Current password: ", "New password: ", "Retype new password: ", each answered once; a fourth is passwd
        # asking again after refusing the new one, which is the answer
        # (a terminal ends its lines in \r\n: without the \r taken out only the last prompt matched, and the second
        # was never answered)
        asked = len(re.findall(r"password: ?$", out.replace("\r", ""), re.I | re.M))
        if asked > 3:
            break
        while answers and asked > 3 - len(answers):
            os.write(fd, (answers.pop(0) + "\n").encode())
    # its terminal closes a moment before it exits; one still waiting for an answer is stopped
    for _ in range(20):
        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            return os.waitstatus_to_exitcode(status), out
        time.sleep(0.1)
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
    return 1, out


def main():
    now = sys.stdin.readline().rstrip("\n")
    new = sys.stdin.readline().rstrip("\n")
    if new == now:
        print("The new one is the same as the one now")
        return 1
    code, out = change(now, new)
    low = out.lower()
    if code == 0:
        print("changed")
        return 0
    if "short" in low or "longer" in low:
        print("The new one is too short")
    elif "bad password" in low or "simple" in low or "dictionary" in low or "palindrome" in low:
        print("The new one is too easy to guess")
    elif "authentication token manipulation" in low or "authentication failure" in low:
        print("That is not your password now")
    else:
        print("It did not change")
    return 1


if __name__ == "__main__":
    sys.exit(main())
