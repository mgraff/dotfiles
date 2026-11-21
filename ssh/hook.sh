#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# ssh refuse une configuration lisible ou modifiable par d'autres
chmod 700 "$HOME/.ssh"

# Un ~/.ssh/config qui existait déjà vient d'être mis de côté par « dotfiles »
# dans backup/<version>/ pour laisser la place au lien : il devient
# ~/.ssh/config.local, lu en premier, et garde donc la priorité. La copie de
# sauvegarde reste en place. Le hook tourne dans <données>/releases/<version>/ssh.
release=$(dirname "$(pwd -P)")
saved=$(dirname "$(dirname "$release")")/backup/$(basename "$release")/.ssh/config
if [[ -f $saved ]]; then
    if [[ -e $HOME/.ssh/config.local ]]; then
        echo "dotfiles: ~/.ssh/config.local already exists, previous ~/.ssh/config left in $saved" >&2
    else
        cp -p "$saved" "$HOME/.ssh/config.local"
        chmod 600 "$HOME/.ssh/config.local"
        echo "moved previous ~/.ssh/config to ~/.ssh/config.local"
    fi
fi

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
