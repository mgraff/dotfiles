#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# nvim, et les outils dont kickstart.nvim a besoin (installation des plugins,
# recherche Telescope, compilation de telescope-fzf-native)
for tool in nvim git rg make gcc unzip; do
    command -v "$tool" >/dev/null || echo "dotfiles: $tool is not installed (nvim)" >&2
done
