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

# Avertissement en jaune gras pour ne pas le rater, seulement dans un terminal
# (pas de codes couleur dans le journal du timer) et sauf si NO_COLOR est défini
warn() {
    if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
        printf '\e[1;33m%s\e[0m\n' "$*" >&2
    else
        printf '%s\n' "$*" >&2
    fi
}

# Outils dont la configuration a besoin, signalés en une ligne avec la
# commande d'installation de la distribution (nom de paquet : commande(s))
declare -A tools=(
    [git]=git
    [fzf]=fzf             # **<Tab>, Ctrl-R
    [less]=less
    [ripgrep]=rg          # liste des fichiers de **<Tab> (respecte .gitignore)
    [bat]='bat batcat'    # aperçu des fichiers ; « batcat » sur Debian
)
missing=()
for pkg in "${!tools[@]}"; do
    found=
    for cmd in ${tools[$pkg]}; do
        command -v "$cmd" >/dev/null && found=1
    done
    [[ -n $found ]] || missing+=("$pkg")
done
[[ -r /usr/share/bash-completion/bash_completion ]] || missing+=(bash-completion)
if (( ${#missing[@]} )); then
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort)
    install=
    if [[ -r /etc/os-release ]]; then
        # ID et ID_LIKE (ubuntu → debian, rhel → fedora…)
        os=$(. /etc/os-release && echo " ${ID:-} ${ID_LIKE:-} ")
        case $os in
            *" fedora "*) install="sudo dnf install ${missing[*]}" ;;
            *" debian "*) install="sudo apt install ${missing[*]}" ;;
        esac
    fi
    warn "dotfiles: missing tools: ${missing[*]}${install:+ (install: $install)}"
fi
(( BASH_VERSINFO[0] > 4 )) ||
    warn "dotfiles: bash ${BASH_VERSION} is too old, version 5 or later is required"
