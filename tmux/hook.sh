#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# Recharger la configuration dans le serveur tmux en cours, s'il y en a un
if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" && echo "tmux configuration reloaded"
fi
