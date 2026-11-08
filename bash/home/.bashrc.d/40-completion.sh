# Complétion (les réglages de Tab sont dans ~/.inputrc ; les scripts de
# complétion de kubectl, npm, pip… sont générés par le hook du paquet bash)

[[ $- == *i* ]] || return 0

shopt -s no_empty_cmd_completion  # Tab sur une ligne vide ne liste pas toutes les commandes

# Complétion floue de fzf (vim **<Tab>) : chargée d'office sur Fedora, pas sur Debian
if command -v fzf >/dev/null && ! declare -F _fzf_path_completion >/dev/null; then
    for __fzf in /usr/share/fzf/shell/completion.bash \
                 /usr/share/doc/fzf/examples/completion.bash \
                 /usr/share/bash-completion/completions/fzf; do
        if [[ -r $__fzf ]]; then
            . "$__fzf"
            break
        fi
    done
    unset __fzf
fi
