# Environnement (module environment et zprofile de Prezto)

# Éditeur : git commit, crontab -e, sudoedit, systemctl edit, Ctrl-X Ctrl-E…
# nvim s'il est installé, sinon vim, sinon vi (vim-tiny sur une Debian minimale)
for __editor in nvim vim vi; do
    if command -v "$__editor" >/dev/null; then
        export EDITOR=$__editor VISUAL=$__editor
        break
    fi
done
unset __editor

# Pager
#   -F  pas de pager si le texte tient sur un écran (git le met de lui-même
#       quand LESS est vide, plus une fois LESS définie)
#   -g  surligne seulement l'occurrence courante de la recherche
#   -i  recherche insensible à la casse, sauf si le motif contient une majuscule
#   -M  barre d'état détaillée
#   -R  garde les couleurs
#   -w  surligne la première nouvelle ligne après un saut de page
#   -X  le texte reste affiché à la sortie
#   -z-4  un saut de page garde 4 lignes de contexte
export PAGER=less
export LESS='-F -g -i -M -R -w -X -z-4'

# Pages de manuel en couleur : gras en rouge, souligné en bleu.
# -P -c : groff produit du gras/souligné « à l'ancienne » que less sait colorer
export MANPAGER='less --use-color -Dd+r -Du+b'
export MANROFFOPT='-P -c'

# less ouvre aussi archives, PDF… : Fedora le règle au niveau du système, pas Debian
if [[ -z ${LESSOPEN-} ]] && command -v lesspipe >/dev/null; then
    eval "$(SHELL=/bin/sh lesspipe)"
fi

[[ $- == *i* ]] || return 0

shopt -s checkjobs  # exit prévient s'il reste des tâches ; un 2e exit force

# Saisie de la phrase de passe GPG dans le terminal (réglé par Fedora, pas Debian)
export GPG_TTY=${GPG_TTY:-$(tty)}

# Agent ssh transmis (ssh -A) dans tmux : un pane garderait le SSH_AUTH_SOCK
# de la connexion ssh qui l'a créé, et ce socket disparaît avec elle (git, ssh…
# échouent alors avec « Permission denied (publickey) »). Les shells de tmux
# utilisent donc un lien stable, ~/.ssh/agent.sock, que chaque shell ouvert
# hors de tmux (celui d'une nouvelle connexion ssh) fait pointer vers son agent.
__ssh_agent_link=$HOME/.ssh/agent.sock

# Fait pointer le lien vers le socket $1 (sauf si c'est le lien lui-même)
__ssh_agent_set() {
    [[ $1 != "$__ssh_agent_link" && -S $1 && -d $HOME/.ssh ]] &&
        ln -sfn "$1" "$__ssh_agent_link"
}

if [[ -z ${TMUX-} ]]; then
    __ssh_agent_set "${SSH_AUTH_SOCK-}"
else
    [[ -S $__ssh_agent_link ]] || __ssh_agent_set "${SSH_AUTH_SOCK-}"
    [[ -S $__ssh_agent_link ]] && export SSH_AUTH_SOCK=$__ssh_agent_link
fi

# Avant chaque prompt dans tmux : si l'agent a disparu (connexion fermée sans
# qu'une autre ait repointé le lien), prendre le plus récent des agents
# transmis encore présents (sshd les crée dans /tmp/ssh-*/agent.<pid>)
__ssh_agent_refresh() {
    local status=$? sock best=
    if [[ -n ${TMUX-} && -n ${SSH_AUTH_SOCK-} && ! -S $SSH_AUTH_SOCK ]]; then
        for sock in /tmp/ssh-*/agent.*; do
            [[ -S $sock && ( -z $best || $sock -nt $best ) ]] && best=$sock
        done
        if [[ -n $best ]] && __ssh_agent_set "$best"; then
            export SSH_AUTH_SOCK=$__ssh_agent_link
        fi
    fi
    return $status
}
PROMPT_COMMAND+=(__ssh_agent_refresh)

# bc : calcul avec 2 décimales (tronquées, pas arrondies : 2/3 donne .66 ;
# « scale=5 » pour plus de précision) et fonctions mathématiques (-l : s(),
# c(), l(), e(), sqrt()), sans la bannière de démarrage (-q).
# Fonction plutôt que BC_ENV_ARGS : exportée, cette variable changerait aussi
# le résultat des scripts qui utilisent bc (10/3 y donnerait 3.33 et non 3).
bc() {
    command bc -lq <(echo scale=2) "$@"
}
