#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# ssh refuse une configuration lisible ou modifiable par d'autres
chmod 700 "$HOME/.ssh"

# Réglages propres à la machine, lus avant ceux du dépôt (voir ~/.ssh/config)
if [[ ! -e $HOME/.ssh/config.local ]]; then
    cat >"$HOME/.ssh/config.local" <<'LOCAL'
# Réglages ssh propres à cette machine, hors du dépôt dotfiles.
# Ils l'emportent sur ~/.ssh/config. Exemple :
#
# Host serveur
#     HostName serveur.example.com
#     User admin
#     IdentityFile ~/.ssh/id_serveur
LOCAL
    chmod 600 "$HOME/.ssh/config.local"
    echo "created ~/.ssh/config.local"
fi

# Sockets des connexions partagées (ControlPath)
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"
