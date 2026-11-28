#!/usr/bin/env bash
# dotfiles : installe et tient à jour les mêmes dotfiles sur toutes les machines.
#
#   dotfiles install <dépôt>   première installation ; <dépôt> est une adresse
#                              git (https://github.com/…/dotfiles.git) ou un
#                              chemin local
#   dotfiles update            récupère le dernier commit et l'applique
#   dotfiles switch <branche>  suit une autre branche (pour tester), et
#                              l'installe ; « switch master » pour revenir
#   dotfiles rollback          revient à la version précédente
#   dotfiles status            dépôt, version installée, fichiers gérés
#
# Organisation du dépôt : un dossier par paquet (bash, nvim, tmux…)
#   <paquet>/home/…   fichiers à placer dans ~, même arborescence
#   <paquet>/hook.sh  facultatif, lancé après chaque installation ou mise à jour
#   <paquet>/check.sh facultatif, vérifications sans effet (outils manquants…),
#                     lancé à chaque update (avant les hooks), même déjà à
#                     jour, et par status ;
#                     ce qu'il affiche est montré en jaune
#   <paquet>/requires facultatif, une commande par ligne : le paquet n'est
#                     installé que si toutes ces commandes sont présentes
#
# Le dépôt est cloné dans ~/.local/share/dotfiles/repo.git. Chaque commit
# installé est extrait dans releases/<date>-<commit>, et « current » pointe vers
# la version active. Les fichiers de ~ sont des liens
# vers « current » : changer de version est donc instantané pour tous à la fois.
# Un fichier existant à la place d'un lien est déplacé dans backup/<date>.
#
# Branche suivie : celle de $CONFIG/branch, sinon la branche par défaut du
# dépôt. Si elle disparaît du dépôt (supprimée après un merge), la mise à jour
# suivante revient sur la branche par défaut.

set -euo pipefail

DATA=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles
REPO=$DATA/repo.git
KEEP=5  # versions conservées pour rollback

say()  { printf '%s\n' "$*"; }
# Avertissement en jaune gras dans un terminal (pas de codes couleur dans le
# journal du timer), sauf si NO_COLOR est défini
attention() {
    if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
        printf '\e[1;33m%s\e[0m\n' "$*" >&2
    else
        printf '%s\n' "$*" >&2
    fi
}
warn() { printf 'dotfiles: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

# Branche par défaut du dépôt (celle de HEAD au moment du clone)
default_branch() {
    git --git-dir="$REPO" symbolic-ref --short HEAD 2>/dev/null || echo master
}

# Branche suivie
branch() {
    if [[ -f $CONFIG/branch ]]; then
        cat "$CONFIG/branch"
    else
        default_branch
    fi
}

# Récupère les derniers commits du dépôt et affiche l'identifiant du plus
# récent de la branche suivie
fetch() {
    local source branch
    source=$(<"$CONFIG/source")
    if [[ ! -d $REPO ]]; then
        git clone --quiet --bare "$source" "$REPO" 9>&- || die "cannot clone $source"
    else
        git --git-dir="$REPO" fetch --quiet --prune "$source" '+refs/heads/*:refs/heads/*' 9>&- ||
            die "cannot fetch $source"
    fi
    if [[ -f $CONFIG/branch ]]; then
        branch=$(<"$CONFIG/branch")
        if ! git --git-dir="$REPO" show-ref --verify --quiet "refs/heads/$branch"; then
            warn "branch $branch no longer exists, back to $(default_branch)"
            rm -f "$CONFIG/branch"
        fi
    fi
    git --git-dir="$REPO" rev-parse "refs/heads/$(branch)^{commit}"
}

# Vérifie la syntaxe des fichiers shell avant de les installer
check() {
    local dir=$1 f errors=0
    [[ -f $dir/install.sh ]] || die "install.sh is missing from the repository"
    while IFS= read -r -d '' f; do
        bash -n "$f" 2>/dev/null || { warn "syntax error: ${f#"$dir"/}"; errors=1; }
    done < <(find "$dir" -type f \( -name '*.sh' -o -name '.bash*' -o -path '*/.bashrc.d/*' -o -path '*/bash-completion/completions/*' -o -path '*/.local/bin/*' \) -print0)
    (( ! errors )) || die "version rejected, nothing was changed"
}

# Paquets de la version active (dossiers avec home/ ou hook.sh)
packages() {
    local pkg
    for pkg in "$DATA"/current/*/; do
        pkg=${pkg%/}
        if [[ -d $pkg/home || -f $pkg/hook.sh ]]; then
            printf '%s\n' "${pkg##*/}"
        fi
    done
}

# Commandes requises par le paquet $1 (fichier requires) qui ne sont pas
# installées ; rien si le paquet peut être installé
missing() {
    local file=$DATA/current/$1/requires cmd
    [[ -f $file ]] || return 0
    while read -r cmd; do
        [[ -z $cmd || $cmd == '#'* ]] && continue
        if ! command -v "$cmd" >/dev/null; then
            printf '%s ' "$cmd"
        fi
    done <"$file"
}

# Paquets dont toutes les commandes requises sont installées
enabled() {
    local name
    packages | while read -r name; do
        if [[ -z $(missing "$name") ]]; then
            printf '%s\n' "$name"
        fi
    done
}

# Crée les liens de ~ vers la version active et retire ceux devenus inutiles,
# y compris ceux des paquets dont un outil requis a été désinstallé
link() {
    local stamp=$1 name pkg rel src dst old
    local new_list=$DATA/links.new
    : >"$new_list"

    while read -r name; do
        pkg=$DATA/current/$name
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
    done < <(enabled)

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

# Active la version $1 (nom d'un dossier de releases), affiche le message $2
# une fois les fichiers en place, puis les avertissements (check.sh), puis
# lance les hooks (rechargement de tmux…)
activate() {
    local release=$1 message=$2 name miss
    ln -sfn "releases/$release" "$DATA/current.new"
    mv -T "$DATA/current.new" "$DATA/current"
    link "$release"
    say "$message"
    checks
    while read -r name; do
        miss=$(missing "$name")
        if [[ -n $miss ]]; then
            say "skipped $name: ${miss% } not installed"
        elif [[ -f $DATA/current/$name/hook.sh ]]; then
            (cd "$DATA/current/$name" && bash ./hook.sh </dev/null 9>&-) || warn "hook failed: $name"
        fi
    done < <(packages)
    enabled >"$DATA/packages"
}

# Vérifications des paquets actifs (<paquet>/check.sh), affichées en jaune
checks() {
    local name line
    while read -r name; do
        [[ -f $DATA/current/$name/check.sh ]] || continue
        while IFS= read -r line; do
            attention "$line"
        done < <(cd "$DATA/current/$name" && bash ./check.sh </dev/null 2>&1 9>&-)
    done < <(enabled)
}

# Unités systemd de la mise à jour automatique : écrites seulement si elles
# ont changé (puis daemon-reload), à l'installation et à chaque update pour
# que les machines déjà installées reçoivent les nouvelles versions.
# Code de retour 1 sans instance systemd utilisateur.
units() {
    command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1 ||
        return 1
    local dir=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user changed= service timer
    service=$(cat <<'EOF'
[Unit]
Description=Update dotfiles
# Si une mise à jour échoue (réseau pas encore prêt à l'ouverture de session,
# GitHub injoignable…), elle est relancée toutes les 5 minutes : le service ne
# passe en échec que si ça dure (10 essais en une heure).
StartLimitIntervalSec=1h
StartLimitBurst=10

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash %h/.local/share/dotfiles/current/install.sh update
Restart=on-failure
RestartSec=5min
EOF
)
    timer=$(cat <<'EOF'
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
)
    mkdir -p "$dir"
    if [[ ! -f $dir/dotfiles-update.service || $(<"$dir/dotfiles-update.service") != "$service" ]]; then
        printf '%s\n' "$service" >"$dir/dotfiles-update.service"
        changed=1
    fi
    if [[ ! -f $dir/dotfiles-update.timer || $(<"$dir/dotfiles-update.timer") != "$timer" ]]; then
        printf '%s\n' "$timer" >"$dir/dotfiles-update.timer"
        changed=1
    fi
    [[ -z $changed ]] || systemctl --user daemon-reload
}

# Commande « dotfiles » et mise à jour quotidienne automatique
setup() {
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$DATA/current/install.sh" "$HOME/.local/bin/dotfiles"
    units || {
        warn "systemd user instance unavailable: no automatic updates (run \"dotfiles update\")"
        return 0
    }
    systemctl --user enable --now dotfiles-update.timer >/dev/null 2>&1 &&
        say "automatic updates: daily (systemctl --user status dotfiles-update.timer)"
}

# Date de la dernière mise à jour réussie (installée ou déjà à jour), pour
# « dotfiles status »
updated() {
    date +%s >"$DATA/last-update"
}

# Date $1 (secondes depuis 1970) suivie de l'écart avec maintenant, passé ou
# à venir : « 2026-11-28 11:59 (5 min ago) », « 2026-11-29 00:47 (in 12 h) »
stamp() {
    local s=$(( $(date +%s) - $1 )) delta
    (( s >= 0 )) || s=$(( -s ))
    if (( s < 3600 )); then
        delta="$(( s / 60 )) min"
    elif (( s < 86400 )); then
        delta="$(( s / 3600 )) h"
    elif (( s < 2 * 86400 )); then
        delta="1 day"
    else
        delta="$(( s / 86400 )) days"
    fi
    if (( $1 > $(date +%s) )); then
        delta="in $delta"
    else
        delta="$delta ago"
    fi
    printf '%s (%s)\n' "$(date -d "@$1" '+%F %R')" "$delta"
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
    # Verrou tenu par le descripteur 9 jusqu'à la fin. git, les hooks et les
    # check.sh sont lancés avec ce descripteur fermé (« 9>&- ») : sinon un
    # démon qu'ils démarrent (« op daemon », lancé par « op completion »)
    # en hériterait, garderait le verrou et bloquerait les mises à jour.
    exec 9>"$DATA/lock"
    flock -n 9 || die "an update is already running"
    units || true

    local commit tmp name
    commit=$(fetch)
    if [[ $(readlink "$DATA/current" 2>/dev/null) == *-"${commit:0:7}" ]]; then
        if [[ $(enabled) == "$(cat "$DATA/packages" 2>/dev/null)" ]]; then
            say "already up to date (${commit:0:7})"
            checks
        else
            # Un outil requis a été installé ou désinstallé depuis
            activate "$(basename "$(readlink "$DATA/current")")" "packages updated (${commit:0:7})"
        fi
        updated
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
    activate "$name" "installed $(git --git-dir="$REPO" log -1 --format='%h "%s"' "$commit") from $(branch)"
    prune
    updated
}

cmd_install() {
    local source=${1:-}
    [[ -n $source ]] || die "usage: dotfiles install <git repository>"
    [[ -d $source ]] && source=$(cd "$source" && pwd)
    # Nouveau dépôt : repartir d'un clone neuf
    if [[ $(cat "$CONFIG/source" 2>/dev/null) != "$source" ]]; then
        rm -rf "$REPO"
        rm -f "$CONFIG/branch"
    fi
    mkdir -p "$CONFIG"
    printf '%s\n' "$source" >"$CONFIG/source"
    cmd_update
    setup
}

cmd_switch() {
    local branch=${1:-} source
    [[ -n $branch ]] || die "usage: dotfiles switch <branch>"
    [[ -f $CONFIG/source ]] || die "no repository configured: dotfiles install <repository>"
    source=$(<"$CONFIG/source")
    git ls-remote --exit-code --heads "$source" "refs/heads/$branch" >/dev/null ||
        die "no branch $branch in $source"
    if [[ $branch == "$(default_branch)" ]]; then
        rm -f "$CONFIG/branch"
    else
        mkdir -p "$CONFIG"
        printf '%s\n' "$branch" >"$CONFIG/branch"
    fi
    cmd_update
}

cmd_rollback() {
    local current previous
    current=$(readlink "$DATA/current") || die "nothing is installed"
    previous=$(ls -1 "$DATA/releases" | sort | awk -v c="${current#releases/}" '$0 < c' | tail -n 1)
    [[ -n $previous ]] || die "no previous version"
    exec 9>"$DATA/lock"
    flock -n 9 || die "an update is already running"
    activate "$previous" "rolled back to $previous (the next update will reinstall the latest version)"
}

cmd_status() {
    local current
    current=$(readlink "$DATA/current" 2>/dev/null) || current=
    say "repository: $(cat "$CONFIG/source" 2>/dev/null || echo 'none')"
    say "branch:     $(branch)"
    if [[ -n $current ]]; then
        say "version:    ${current#releases/} $(git --git-dir="$REPO" log -1 --format='"%s", %cr' "${current##*-}" 2>/dev/null)"
    else
        say "version:    none"
    fi
    say "available:  $(ls -1 "$DATA/releases" 2>/dev/null | sort -r | tr '\n' ' ')"
    if [[ -n $current ]]; then
        local name skipped=
        for name in $(packages); do
            if [[ -n $(missing "$name") ]]; then
                skipped+="$name ($(missing "$name" | sed 's/ $//') not installed) "
            fi
        done
        say "packages:   $(enabled | tr '\n' ' ')"
        [[ -n $skipped ]] && say "skipped:    $skipped"
    fi
    say "managed files: $(wc -l <"$DATA/links" 2>/dev/null || echo 0)"
    if [[ -f $DATA/last-update ]]; then
        say "last update: $(stamp "$(<"$DATA/last-update")")"
    fi
    if command -v systemctl >/dev/null && systemctl --user is-enabled dotfiles-update.timer >/dev/null 2>&1; then
        local next
        next=$(systemctl --user show dotfiles-update.timer -p NextElapseUSecRealtime --value --timestamp=unix)
        [[ $next == @* ]] && say "next update: $(stamp "${next#@}")"
    fi
    update_failure
    [[ -n $current ]] && checks
}

# Mise à jour automatique en échec (le « ⚠ » de la barre d'état de tmux) :
# l'affiche en jaune avec le dernier message d'erreur de l'installateur
update_failure() {
    command -v systemctl >/dev/null &&
        systemctl --user is-failed --quiet dotfiles-update.service 2>/dev/null || return 0
    local error
    error=$(journalctl --user -u dotfiles-update.service -o cat -n 200 --no-pager 2>/dev/null |
        grep '^dotfiles: ' | tail -n 1)
    attention "automatic update failed${error:+: ${error#dotfiles: }}"
    attention "  details: journalctl --user -u dotfiles-update"
}

usage() {
    cat <<'EOF'
dotfiles: install and keep the same dotfiles up to date on every machine

  dotfiles install <repository>  first install; <repository> is a git URL
                                 (https://github.com/.../dotfiles.git) or a local path
  dotfiles update                fetch the latest commit and apply it
  dotfiles switch <branch>       follow another branch (to test it) and install it;
                                 "dotfiles switch master" to come back
  dotfiles rollback              go back to the previous version
  dotfiles status                repository, installed version, managed files
EOF
}

case ${1:-} in
    install)  shift; cmd_install "$@" ;;
    update)   cmd_update ;;
    switch)   shift; cmd_switch "$@" ;;
    rollback) cmd_rollback ;;
    status)   cmd_status ;;
    *)        usage; exit 1 ;;
esac
