#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# ~/.gitconfig doit exister : sans lui, « git config --global » écrirait dans
# ~/.config/git/config, qui est un lien vers la version installée.
[[ -e $HOME/.gitconfig ]] || : >"$HOME/.gitconfig"
