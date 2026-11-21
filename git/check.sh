#!/usr/bin/env bash
# Lancé par « dotfiles » à chaque update (même déjà à jour) et par
# « dotfiles status » : ne fait que vérifier, ce qu'il affiche est un
# avertissement (en jaune dans un terminal).

# Identité : propre à chaque machine, donc dans ~/.gitconfig et pas dans le dépôt
if [[ -z $(git config --global user.email) ]]; then
    echo 'dotfiles: git identity is not set, run:'
    echo '  git config --global user.name "Your Name"'
    echo '  git config --global user.email you@example.com'
fi
