# fzf : apparence, liste des fichiers pour **<Tab>, et Ctrl-R.
# La complétion **<Tab> elle-même est chargée par 40-completion.sh.

[[ $- == *i* ]] || return 0
command -v fzf >/dev/null || return 0

# Apparence, pour Ctrl-R, **<Tab> et les « … | fzf » tapés à la main : sous la
# ligne de commande (40 % de la hauteur) au lieu de plein écran, saisie en
# haut, couleurs de la barre tmux ; Shift-↑/↓ font défiler l'aperçu par
# demi-page (au lieu d'une ligne).
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline \
--color=hl:red,hl+:bright-red,pointer:bright-red,marker:bright-red,prompt:bright-red,spinner:bright-red,info:245,border:245 \
--bind=shift-down:preview-half-page-down,shift-up:preview-half-page-up"

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

# Complétion floue **<Tab> et raccourcis clavier, fournis par fzf lui-même.
# On ne garde que Ctrl-R : Ctrl-T (fichier) et Alt-C (cd) reprennent leur
# rôle habituel dans bash.
eval "$(fzf --bash)"
bind '"\C-t": transpose-chars'
bind '"\ec": capitalize-word'

# git add/diff/restore **<Tab> : seulement les fichiers concernés (modifiés,
# nouveaux, ou déjà indexés avec --staged/--cached), sélection multiple, et à
# droite le diff du fichier survolé (le contenu, coloré par bat, s'il est
# nouveau). Les autres commandes git gardent la liste complète.
if declare -F _fzf_complete >/dev/null; then
    # bat s'appelle batcat sur Debian
    __fzf_bat=$(command -v bat || command -v batcat) || __fzf_bat=
    _fzf_complete_git() {
        local sub=${COMP_WORDS[1]} cached= w list preview
        local cur=${COMP_WORDS[COMP_CWORD]}
        # Tab sans ** ou autre sous-commande : comportement habituel
        if [[ $cur != *"${FZF_COMPLETION_TRIGGER-**}" || ! $sub =~ ^(add|diff|restore)$ ]]; then
            _fzf_path_completion "$@"
            return
        fi
        for w in "${COMP_WORDS[@]:2}"; do
            [[ $w == --staged || $w == --cached ]] && cached=1
        done
        if [[ $sub == add ]]; then
            list=(git ls-files -z --modified --others --exclude-standard)
        elif [[ -n $cached ]]; then
            list=(git diff -z --cached --name-only --relative)
        else
            list=(git ls-files -z --modified)
        fi
        if [[ -n $cached ]]; then
            preview='git diff --cached --color=always -- {}'
        else
            local show=cat
            [[ -n $__fzf_bat ]] && show="$__fzf_bat --color=always --style=numbers"
            preview="if git ls-files --error-unmatch -- {} >/dev/null 2>&1; then git diff --color=always -- {}; else $show -- {}; fi"
        fi
        _fzf_complete --multi --height=80% --preview="$preview" --preview-window=right,60% -- "$@" \
            < <("${list[@]}" 2>/dev/null | tr '\0' '\n' | sort -u)
    }
    # Noms de fichiers protégés (espaces…) sur la ligne de commande
    _fzf_complete_git_post() {
        local f
        while IFS= read -r f; do
            printf '%q\n' "$f"
        done
    }
    complete -F _fzf_complete_git -o default -o bashdefault git
fi

# Ctrl-R : recherche dans l'historique avec fzf (liste filtrable, recherche
# floue) au lieu de la recherche de bash. ↑/↓ gardent la recherche par
# sous-chaîne de 20-history-search.sh.
