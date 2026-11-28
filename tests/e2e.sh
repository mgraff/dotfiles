#!/usr/bin/env bash
# Test de bout en bout d'une branche, dans un HOME jetable : rien n'est modifié
# dans le vrai ~, ni dans le serveur tmux en cours, ni dans systemd.
#
#   tests/e2e.sh [--debian|--fedora] [--keep] [branche] [base]
#
#   branche   branche à tester (par défaut : la branche courante du dépôt)
#   base      branche installée d'abord (par défaut : master)
#   --debian  lance le même test dans un conteneur Debian 13 (podman)
#   --fedora  lance le même test dans un conteneur Fedora 45 (podman)
#   --keep    garde le HOME jetable pour l'inspecter
#
# Le dépôt local sert de source : les commits non poussés sont testés aussi,
# mais pas les modifications non commitées.
#
# Étapes, comme sur une vraie machine :
#   1. installation de <base>
#   2. passage sur <branche> par l'installateur de <base> (c'est toujours
#      l'installateur déjà installé qui fait la mise à jour)
#   3. réactivation par l'installateur de <branche>
#   4. update déjà à jour, puis status
#   5. ouverture d'un bash interactif : aucune erreur ne doit s'afficher
# Un serveur tmux de test tourne pendant le test, pour le hook tmux.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
system= keep=
args=()
for arg; do
    case $arg in
        --debian|--fedora) system=${arg#--} ;;
        --keep)   keep=1 ;;
        -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) echo "e2e: unknown option $arg" >&2; exit 2 ;;
        *) args+=("$arg") ;;
    esac
done
branch=${args[0]:-$(git -C "$repo" branch --show-current)}
base=${args[1]:-master}
for b in "$base" "$branch"; do
    git -C "$repo" rev-parse --verify --quiet "refs/heads/$b" >/dev/null ||
        { echo "e2e: no local branch $b" >&2; exit 2; }
done
[[ -z $(git -C "$repo" status --porcelain) ]] ||
    echo "e2e: warning: uncommitted changes are not tested" >&2

# Même test dans un conteneur Debian 13 ou Fedora 45, avec les outils que
# check.sh demande : le dépôt est monté en lecture seule
if [[ -n $system ]]; then
    case $system in
        debian)
            image=docker.io/library/debian:13
            install='apt-get -qq update >/dev/null &&
                apt-get -qq install -y git tmux fzf ripgrep bat bash-completion less procps' ;;
        fedora)
            image=registry.fedoraproject.org/fedora:45
            install='dnf -q install -y git tmux fzf ripgrep bat bash-completion less procps-ng util-linux-core findutils' ;;
    esac
    exec podman run --rm -v "$repo:/repo:ro,Z" "$image" bash -c "
        { $install; } >/dev/null 2>&1 || { echo 'e2e: package installation failed' >&2; exit 1; }
        git config --global safe.directory '*'
        exec bash /repo/tests/e2e.sh \"\$@\"" e2e "$branch" "$base"
fi

# Dossier court : les sockets tmux sont limités à 108 caractères
tmp=$(mktemp -d /tmp/e2e.XXXX)
cleanup() {
    tmux kill-server 2>/dev/null || true
    if [[ -n $keep ]]; then
        echo "e2e: kept $tmp/home" >&2
    else
        rm -rf "$tmp"
    fi
}
trap cleanup EXIT

export HOME=$tmp/home TMUX_TMPDIR=$tmp GIT_CONFIG_NOSYSTEM=1
unset TMUX XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
mkdir -p "$HOME/.config/dotfiles"
# Identité git de test : sans elle, l'avertissement de git/check.sh
# apparaîtrait à chaque étape et masquerait les autres
printf '[user]\n\tname = e2e\n\temail = e2e@example.com\n' >"$HOME/.gitconfig"
data=$HOME/.local/share/dotfiles
# « dotfiles install » activerait aussi le timer systemd de la vraie session :
# on écrit sa configuration à la main et on lance « update »
echo "$repo" >"$HOME/.config/dotfiles/source"
tmux new-session -d -s e2e

failed=0
step() {
    if [[ -t 1 ]]; then
        printf '\n\e[1m=== %s\e[0m\n' "$1"
    else
        printf '\n=== %s\n' "$1"
    fi
    shift
    "$@" || { echo "e2e: FAILED (exit $?)" >&2; failed=1; }
}
installer() {
    bash "$data/current/install.sh" "$@"
}

echo "$base" >"$HOME/.config/dotfiles/branch"
step "1. install $base" bash <(git -C "$repo" show "$base:install.sh") update
echo "$branch" >"$HOME/.config/dotfiles/branch"
step "2. switch to $branch (installer of $base)" installer update
: >"$data/packages"  # liste vide : update réactive la version installée
step "3. reactivate (installer of $branch)" installer update
step "4a. update, already up to date" installer update
step "4b. status" installer status

shell_errors() {
    local out
    # Sans terminal, bash -i signale l'absence de contrôle des tâches : ignoré
    out=$(bash -i -c : 2>&1 </dev/null |
        grep -vE 'job control|terminal process group|^$' || true)
    if [[ -n $out ]]; then
        printf '%s\n' "$out"
        return 1
    fi
    echo "no error"
}
step "5. interactive bash" shell_errors

echo
if (( failed )); then
    echo "e2e: some steps failed" >&2
    exit 1
fi
echo "e2e: all steps passed"
