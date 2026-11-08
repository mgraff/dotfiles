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
