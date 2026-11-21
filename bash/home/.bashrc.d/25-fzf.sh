# fzf : apparence, liste des fichiers pour **<Tab>, et Ctrl-R.
# La complétion **<Tab> elle-même est chargée par 40-completion.sh.

[[ $- == *i* ]] || return 0
command -v fzf >/dev/null || return 0

# Apparence, pour Ctrl-R, **<Tab> et les « … | fzf » tapés à la main : sous la
# ligne de commande (40 % de la hauteur) au lieu de plein écran, saisie en
# haut, couleurs de la barre tmux. Options compatibles avec le fzf de Debian 12.
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline \
--color=hl:red,hl+:bright-red,pointer:bright-red,marker:bright-red,prompt:bright-red,spinner:bright-red,info:245,border:245"

# Fichiers proposés par **<Tab> : ceux que liste rg, qui respecte les
# .gitignore (.venv/, build/…) ; fichiers cachés compris, sauf .git/ et
# node_modules/. Sans rg, fzf garde sa propre recherche.
if command -v rg >/dev/null; then
    # $1 : dossier de départ (« . » pour le dossier courant)
    __fzf_rg_files() {
        rg --files --hidden --follow --no-messages \
            --glob '!.git/' --glob '!node_modules/' -- "$1" |
            if [[ $1 == . ]]; then sed 's|^\./||'; else cat; fi
    }
    _fzf_compgen_path() {
        __fzf_rg_files "$1"
    }
    # cd **<Tab> : les dossiers qui contiennent ces fichiers
    _fzf_compgen_dir() {
        __fzf_rg_files "$1" | awk -F/ '{
            p = ""
            for (i = 1; i < NF; i++) {
                p = (i == 1 ? $1 : p "/" $i)
                if (p != "" && !seen[p]++) print p
            }
        }'
    }
fi

# Ctrl-R : recherche dans l'historique avec fzf (liste filtrable, recherche
# floue) au lieu de la recherche de bash. ↑/↓ gardent la recherche par
# sous-chaîne de 20-history-search.sh.

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
