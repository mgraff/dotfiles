# .bashrc, identique sur toutes les machines (Fedora, Debian)

# Réglages globaux : Fedora les met dans /etc/bashrc, qu'il faut charger soi-même ;
# Debian dans /etc/bash.bashrc, que bash charge tout seul
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Commandes personnelles
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# bash-completion : chargé par /etc/bashrc sur Fedora, pas par Debian
if [[ $- == *i* && -z ${BASH_COMPLETION_VERSINFO-} ]] && ! shopt -oq posix &&
    [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Configuration personnelle, un fichier par sujet
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
