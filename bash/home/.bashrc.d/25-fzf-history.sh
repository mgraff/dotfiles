# Ctrl-R : recherche dans l'historique avec fzf (liste filtrable, recherche
# floue) au lieu de la recherche de bash. ↑/↓ gardent la recherche par
# sous-chaîne de 20-history-search.sh.

[[ $- == *i* ]] || return 0
command -v fzf >/dev/null || return 0

# Script de fzf selon la distribution : Fedora, Debian
for __fzf in /usr/share/fzf/shell/key-bindings.bash \
             /usr/share/doc/fzf/examples/key-bindings.bash; do
    [[ -r $__fzf ]] && break
done
if [[ -r $__fzf ]]; then
    . "$__fzf"

    # Le script lie aussi Ctrl-T (fichier) et Alt-C (cd) : on ne garde que
    # Ctrl-R et on rend à ces touches leur rôle habituel dans bash.
    bind '"\C-t": transpose-chars'
    bind '"\ec": capitalize-word'

    # Récupérer d'abord les commandes lancées dans les autres terminaux
    # (historique partagé, 10-history.sh), comme le fait ↑
    if declare -F __fzf_history__ >/dev/null && declare -F __history_sync >/dev/null; then
        eval "__fzf_history_orig() $(declare -f __fzf_history__ | tail -n +2)"
        __fzf_history__() {
            __history_sync
            __fzf_history_orig "$@"
        }
    fi
fi
unset __fzf
