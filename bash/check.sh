#!/usr/bin/env bash
# Lancé par « dotfiles » à chaque update (même déjà à jour) et par
# « dotfiles status » : ne fait que vérifier, ce qu'il affiche est un
# avertissement (en jaune dans un terminal).

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
    echo "dotfiles: missing tools: ${missing[*]}${install:+ (install: $install)}"
fi
(( BASH_VERSINFO[0] > 4 )) ||
    echo "dotfiles: bash ${BASH_VERSION} is too old, version 5 or later is required"
