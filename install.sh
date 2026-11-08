#!/usr/bin/env bash
# dotfiles : installe et tient à jour les mêmes dotfiles sur toutes les machines.
#
#   dotfiles install <dépôt>   première installation ; <dépôt> est une adresse
#                              git (https://github.com/…/dotfiles.git) ou un
#                              chemin local
#   dotfiles update            récupère le dernier commit et l'applique
#   dotfiles rollback          revient à la version précédente
#   dotfiles status            dépôt, version installée, fichiers gérés
#
# Organisation du dépôt : un dossier par paquet (bash, nvim, tmux…)
#   <paquet>/home/…   fichiers à placer dans ~, même arborescence
#   <paquet>/hook.sh  facultatif, lancé après chaque installation ou mise à jour
#
# Le dépôt est cloné dans ~/.local/share/dotfiles/repo.git. Chaque commit
# installé est extrait dans releases/<date>-<commit>, et « current » pointe vers
# la version active. Les fichiers de ~ sont des liens
# vers « current » : changer de version est donc instantané pour tous à la fois.
# Un fichier existant à la place d'un lien est déplacé dans backup/<date>.

set -euo pipefail

DATA=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles
REPO=$DATA/repo.git
KEEP=5  # versions conservées pour rollback

say()  { printf '%s\n' "$*"; }
warn() { printf 'dotfiles: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

# Récupère les derniers commits du dépôt et affiche l'identifiant du plus récent
fetch() {
    local source
    source=$(<"$CONFIG/source")
    if [[ ! -d $REPO ]]; then
        git clone --quiet --bare "$source" "$REPO" || die "cannot clone $source"
    else
        git --git-dir="$REPO" fetch --quiet --prune "$source" '+refs/heads/*:refs/heads/*' ||
            die "cannot fetch $source"
    fi
    git --git-dir="$REPO" rev-parse HEAD
}

# Vérifie la syntaxe des fichiers shell avant de les installer
check() {
    local dir=$1 f errors=0
    [[ -f $dir/install.sh ]] || die "install.sh is missing from the repository"
    while IFS= read -r -d '' f; do
        bash -n "$f" 2>/dev/null || { warn "syntax error: ${f#"$dir"/}"; errors=1; }
    done < <(find "$dir" -type f \( -name '*.sh' -o -name '.bash*' -o -path '*/.bashrc.d/*' \) -print0)
    (( ! errors )) || die "version rejected, nothing was changed"
}

# Crée les liens de ~ vers la version active et retire ceux devenus inutiles
link() {
    local stamp=$1 pkg rel src dst old
    local new_list=$DATA/links.new
    : >"$new_list"

    for pkg in "$DATA"/current/*/; do
        pkg=${pkg%/}
        [[ -d $pkg/home ]] || continue
        while IFS= read -r -d '' src; do
            rel=${src#"$pkg/home/"}
            dst=$HOME/$rel
            src=$DATA/current/${pkg##*/}/home/$rel
            printf '%s\n' "$dst" >>"$new_list"
            [[ -L $dst && $(readlink "$dst") == "$src" ]] && continue
            mkdir -p "${dst%/*}"
            if [[ -e $dst || -L $dst ]]; then
                if [[ -L $dst && $(readlink "$dst") == "$DATA"/* ]]; then
                    rm -f "$dst"
                else
                    mkdir -p "$DATA/backup/$stamp/$(dirname "${dst#"$HOME"/}")"
                    mv "$dst" "$DATA/backup/$stamp/${dst#"$HOME"/}"
                    say "backed up: ~/${dst#"$HOME"/} -> $DATA/backup/$stamp/"
                fi
            fi
            ln -s "$src" "$dst"
        done < <(find "$pkg/home" \( -type f -o -type l \) -print0)
    done

    # Liens de la version précédente qui n'existent plus dans celle-ci
    if [[ -f $DATA/links ]]; then
        while IFS= read -r old; do
            grep -qxF -- "$old" "$new_list" && continue
            [[ -L $old && $(readlink "$old") == "$DATA"/* ]] || continue
            rm -f "$old"
            say "removed: ~/${old#"$HOME"/}"
        done <"$DATA/links"
    fi
    mv "$new_list" "$DATA/links"
}

# Active la version $1 (nom d'un dossier de releases) puis lance les hooks
activate() {
    local release=$1 hook
    ln -sfn "releases/$release" "$DATA/current.new"
    mv -T "$DATA/current.new" "$DATA/current"
    link "$release"
    for hook in "$DATA"/current/*/hook.sh; do
        [[ -f $hook ]] || continue
        (cd "${hook%/*}" && bash ./hook.sh) || warn "hook failed: ${hook#"$DATA/current/"}"
    done
}

# Commande « dotfiles » et mise à jour quotidienne automatique
setup() {
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$DATA/current/install.sh" "$HOME/.local/bin/dotfiles"

    command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1 || {
        warn "systemd user instance unavailable: no automatic updates (run \"dotfiles update\")"
        return 0
    }
    local units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
    mkdir -p "$units"
    cat >"$units/dotfiles-update.service" <<'EOF'
[Unit]
Description=Update dotfiles

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash %h/.local/share/dotfiles/current/install.sh update
EOF
    cat >"$units/dotfiles-update.timer" <<'EOF'
[Unit]
Description=Daily dotfiles update

[Timer]
OnStartupSec=2min
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now dotfiles-update.timer >/dev/null 2>&1 &&
        say "automatic updates: daily (systemctl --user status dotfiles-update.timer)"
}

# Supprime les plus anciennes versions au-delà de $KEEP
prune() {
    local current old
    current=$(readlink "$DATA/current")
    while IFS= read -r old; do
        [[ releases/$old == "$current" ]] || rm -rf "$DATA/releases/$old"
    done < <(ls -1 "$DATA/releases" | sort -r | tail -n +$(( KEEP + 1 )))
}

cmd_update() {
    [[ -f $CONFIG/source ]] || die "no repository configured: dotfiles install <repository>"
    command -v git >/dev/null || die "git is not installed"
    mkdir -p "$DATA/releases"
    exec 9>"$DATA/lock"
    flock -n 9 || die "an update is already running"

    local commit tmp name
    commit=$(fetch)
    if [[ $(readlink "$DATA/current" 2>/dev/null) == *-"${commit:0:7}" ]]; then
        say "already up to date (${commit:0:7})"
        return
    fi
    tmp=$(mktemp -d "$DATA/tmp.XXXXXX")
    trap "rm -rf $(printf '%q' "$tmp")" EXIT
    git --git-dir="$REPO" archive "$commit" | tar -x -C "$tmp"
    check "$tmp"

    # Le nom commence par la date : il ordonne les versions pour rollback et prune
    while compgen -G "$DATA/releases/$(date +%Y%m%d-%H%M%S)-*" >/dev/null; do sleep 1; done
    name=$(date +%Y%m%d-%H%M%S)-${commit:0:7}
    mv "$tmp" "$DATA/releases/$name"
    activate "$name"
    prune
    say "installed $(git --git-dir="$REPO" log -1 --format='%h "%s"' "$commit")"
}

cmd_install() {
    local source=${1:-}
    [[ -n $source ]] || die "usage: dotfiles install <git repository>"
    [[ -d $source ]] && source=$(cd "$source" && pwd)
    # Nouveau dépôt : repartir d'un clone neuf
    [[ $(cat "$CONFIG/source" 2>/dev/null) == "$source" ]] || rm -rf "$REPO"
    mkdir -p "$CONFIG"
    printf '%s\n' "$source" >"$CONFIG/source"
    cmd_update
    setup
}

cmd_rollback() {
    local current previous
    current=$(readlink "$DATA/current") || die "nothing is installed"
    previous=$(ls -1 "$DATA/releases" | sort | awk -v c="${current#releases/}" '$0 < c' | tail -n 1)
    [[ -n $previous ]] || die "no previous version"
    exec 9>"$DATA/lock"
    flock -n 9 || die "an update is already running"
    activate "$previous"
    say "rolled back to $previous (the next update will reinstall the latest version)"
}

cmd_status() {
    local current
    current=$(readlink "$DATA/current" 2>/dev/null) || current=
    say "repository: $(cat "$CONFIG/source" 2>/dev/null || echo 'none')"
    if [[ -n $current ]]; then
        say "version:    ${current#releases/} $(git --git-dir="$REPO" log -1 --format='"%s", %cr' "${current##*-}" 2>/dev/null)"
    else
        say "version:    none"
    fi
    say "available:  $(ls -1 "$DATA/releases" 2>/dev/null | sort -r | tr '\n' ' ')"
    say "managed files: $(wc -l <"$DATA/links" 2>/dev/null || echo 0)"
    if command -v systemctl >/dev/null && systemctl --user is-enabled dotfiles-update.timer >/dev/null 2>&1; then
        say "next update: $(systemctl --user show dotfiles-update.timer -p NextElapseUSecRealtime --value)"
    fi
}

usage() {
    cat <<'EOF'
dotfiles: install and keep the same dotfiles up to date on every machine

  dotfiles install <repository>  first install; <repository> is a git URL
                                 (https://github.com/.../dotfiles.git) or a local path
  dotfiles update                fetch the latest commit and apply it
  dotfiles rollback              go back to the previous version
  dotfiles status                repository, installed version, managed files
EOF
}

case ${1:-} in
    install)  shift; cmd_install "$@" ;;
    update)   cmd_update ;;
    rollback) cmd_rollback ;;
    status)   cmd_status ;;
    *)        usage; exit 1 ;;
esac
