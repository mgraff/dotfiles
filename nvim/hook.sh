#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

command -v nvim >/dev/null || echo "dotfiles: nvim is not installed" >&2
