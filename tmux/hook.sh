#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

if ! command -v tmux >/dev/null; then
    echo "dotfiles: tmux is not installed" >&2
    exit 0
fi

# Recharger la configuration dans le serveur tmux en cours, s'il y en a un
if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" && echo "tmux configuration reloaded"
fi
