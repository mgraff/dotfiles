#!/usr/bin/env bash
# Lancé par « dotfiles » après chaque installation ou mise à jour

# Scripts de complétion des outils qui n'en fournissent pas. bash-completion
# les charge au premier Tab sur la commande. Ils interrogent l'outil à chaque
# Tab, il suffit donc de les générer une fois, puis après une mise à jour de
# l'outil.
dir=${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions
declare -A generators=(
    [kubectl]='kubectl completion bash'
    [npm]='npm completion'
    [pip]='pip completion --bash'
    [toolbox]='toolbox completion bash'
)

mkdir -p "$dir"
for cmd in "${!generators[@]}"; do
    bin=$(command -v "$cmd") || continue
    [[ -s $dir/$cmd && $dir/$cmd -nt $(readlink -f "$bin") ]] && continue
    if ${generators[$cmd]} >"$dir/$cmd.tmp" 2>/dev/null && [[ -s $dir/$cmd.tmp ]]; then
        mv "$dir/$cmd.tmp" "$dir/$cmd"
        echo "generated completion: $cmd"
    else
        rm -f "$dir/$cmd.tmp"
        echo "dotfiles: \"${generators[$cmd]}\" failed" >&2
    fi
done

# Le script de pip ne s'enregistre que pour « pip »
if [[ -f $dir/pip ]] && command -v pip3 >/dev/null; then
    printf '%s\n' '. "${BASH_SOURCE[0]%/*}/pip"' \
        'complete -o default -F _pip_completion pip3' >"$dir/pip3"
fi

# Outils dont la configuration a besoin
for tool in git fzf less; do
    command -v "$tool" >/dev/null || echo "dotfiles: $tool is not installed" >&2
done
(( BASH_VERSINFO[0] > 4 )) ||
    echo "dotfiles: bash ${BASH_VERSION} is too old, version 5 or later is required" >&2
