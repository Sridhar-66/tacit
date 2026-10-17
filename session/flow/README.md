# session/flow/

Flow, the desktop's dictation (hold the key, speak, release), as it ran on 2026-10-08: `flowd` (Python; ran from
~/.local/bin with the venv ~/.local/share/flow/venv, whose packages are `requirements.txt`) and its user service.
The shell's half is services/Dictation.qml and the notch pill. It signs in with the owner's gcloud user token to the
Google project martida-flow.

Not packaged yet: for anyone but the owner, dictation needs its own sign-in and billing (a product decision), and
google-cloud-speech is not in Arch's repositories.
