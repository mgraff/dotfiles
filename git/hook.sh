#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# ~/.gitconfig doit exister : sans lui, « git config --global » écrirait dans
# ~/.config/git/config, qui est un lien vers la version installée.
[[ -e $HOME/.gitconfig ]] || : >"$HOME/.gitconfig"

# Identité : propre à chaque machine, donc dans ~/.gitconfig et pas dans le dépôt
if [[ -z $(git config --global user.email) ]]; then
    echo 'dotfiles: git identity is not set, run:' >&2
    echo '  git config --global user.name "Your Name"' >&2
    echo '  git config --global user.email you@example.com' >&2
fi
