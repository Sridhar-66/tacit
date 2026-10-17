#!/usr/bin/env bash
# Exit 0 when no collection of the keyring is locked (the in-memory session collection aside); 1 when one is, or when
# no keyring answers. Asks Locked only: nothing of what the keyring holds.
cols=$(busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets \
    org.freedesktop.Secret.Service Collections 2> /dev/null) || exit 1
for c in $(grep -o '"/[^"]*"' <<< "$cols" | tr -d '"'); do
    [[ "$c" == /org/freedesktop/secrets/collection/session ]] && continue
    [[ "$(busctl --user get-property org.freedesktop.secrets "$c" org.freedesktop.Secret.Collection Locked 2> /dev/null)" == "b false" ]] || exit 1
done
exit 0
