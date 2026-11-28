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

# Affichage. Dans un terminal (sortie et erreurs, sauf NO_COLOR ou TERM=dumb) :
# couleurs et icônes Nerd Font, chacune suivie d'une espace. Ailleurs (journal
# du timer, sortie redirigée) : texte brut, avertissements et erreurs préfixés
# par « dotfiles: » (update_failure retrouve ainsi l'erreur dans le journal).
if [[ -t 1 && -t 2 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
    fancy=1
    reset=$'\e[0m' bold=$'\e[1m' dim=$'\e[2m'
    red=$'\e[1;31m' green=$'\e[1;32m' yellow=$'\e[1;33m'
    blue=$'\e[1;34m' purple=$'\e[1;35m' cyan=$'\e[36m'
else
    fancy= reset= bold= dim= red= green= yellow= blue= purple= cyan=
fi

say()  { printf '%s\n' "$*"; }
# Action réussie (version installée…) : «  installed … »
ok()   { say "${green}${fancy:+ }${reset}$*"; }
# Détail d'une action (fichier sauvegardé, sortie d'un hook…) : grisé, en
# retrait sous l'action ; le préfixe « dotfiles: » des hooks devient inutile
note() {
    if [[ -n $fancy ]]; then
        say "${dim}  › ${*#dotfiles: }${reset}"
    else
        say "$*"
    fi
}
# Avertissement en jaune (check.sh, warn) : une ligne « dotfiles: … » reçoit
# l'icône à la place du préfixe, les suivantes (commande à lancer…) restent
# alignées sous son texte
attention() {
    if [[ -z $fancy ]]; then
        printf '%s\n' "$*" >&2
    elif [[ $* == 'dotfiles: '* ]]; then
        printf '%s\n' "${yellow} ${*#dotfiles: }${reset}" >&2
    else
        printf '%s\n' "${yellow}  $*${reset}" >&2
    fi
}
warn() { attention "dotfiles: $*"; }
# Erreur en rouge (die, mise à jour automatique en échec)
error() {
    if [[ -n $fancy ]]; then
        printf '%s\n' "${red} $*${reset}" >&2
    else
        printf 'dotfiles: %s\n' "$*" >&2
    fi
}
die()  { error "$*"; exit 1; }

# Éléments mis en valeur partout : commit (jaune) et branche (violet, comme
# dans le prompt)
hash_()   { printf '%s' "${yellow}${1:0:7}${reset}"; }
branch_() { printf '%s' "${purple}$1${reset}"; }

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
            warn "branch $branch no longer exists, back to $(branch_ "$(default_branch)")"
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
        bash -n "$f" 2>/dev/null || { error "syntax error: ${f#"$dir"/}"; errors=1; }
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
                    note "backed up: ~/${dst#"$HOME"/} -> $DATA/backup/$stamp/"
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
            note "removed: ~/${old#"$HOME"/}"
        done <"$DATA/links"
    fi
    mv "$new_list" "$DATA/links"
}

# Active la version $1 (nom d'un dossier de releases), affiche le message $2
# une fois les fichiers en place, puis les avertissements (check.sh), puis
# lance les hooks (rechargement de tmux…), dont la sortie est affichée en
# détail sous le message
activate() {
    local release=$1 message=$2 name miss
    ln -sfn "releases/$release" "$DATA/current.new"
    mv -T "$DATA/current.new" "$DATA/current"
    link "$release"
    ok "$message"
    checks
    while read -r name; do
        miss=$(missing "$name")
        if [[ -n $miss ]]; then
            note "skipped $name: ${miss% } not installed"
        elif [[ -f $DATA/current/$name/hook.sh ]]; then
            (cd "$DATA/current/$name" && bash ./hook.sh </dev/null 2>&1 9>&-) | details ||
                warn "hook failed: $name"
        fi
    done < <(packages)
    enabled >"$DATA/packages"
}

# Chaque ligne lue sur l'entrée, en détail (note)
details() {
    local line
    while IFS= read -r line; do
        note "$line"
    done
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
    if systemctl --user enable --now dotfiles-update.timer >/dev/null 2>&1; then
        ok "automatic updates: daily"
        note "systemctl --user status dotfiles-update.timer"
    fi
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
    printf '%s %s\n' "$(date -d "@$1" '+%F %R')" "${dim}($delta)${reset}"
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
            ok "already up to date $(hash_ "$commit")"
            checks
        else
            # Un outil requis a été installé ou désinstallé depuis
            activate "$(basename "$(readlink "$DATA/current")")" "packages updated $(hash_ "$commit")"
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
    activate "$name" "installed $(hash_ "$commit") \"$(git --git-dir="$REPO" log -1 --format=%s "$commit")\" from $(branch_ "$(branch)")"
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
    activate "$previous" "rolled back to $(hash_ "${previous##*-}")"
    note "the next update will reinstall the latest version"
}

# Ligne de « dotfiles status » : icône $1, libellé $2, valeur $3
field() {
    if [[ -n $fancy ]]; then
        printf '%s\n' "${blue}$1 ${reset}${dim}$(printf '%-11s' "$2")${reset} $3"
    else
        printf '%-12s %s\n' "$2:" "$3"
    fi
}

cmd_status() {
    local current branch value release name skipped= last next
    current=$(readlink "$DATA/current" 2>/dev/null) || current=
    field  repository "$(cat "$CONFIG/source" 2>/dev/null || echo none)"

    # Branche de test en jaune, avec la commande pour revenir
    branch=$(branch)
    if [[ $branch == "$(default_branch)" ]]; then
        field  branch "$(branch_ "$branch")"
    else
        field  branch "${yellow}$branch${reset} ${dim}(test branch: \"dotfiles switch $(default_branch)\" to come back)${reset}"
    fi

    if [[ -n $current ]]; then
        field  version "$(hash_ "${current##*-}") $(git --git-dir="$REPO" log -1 --format='"%s"' "${current##*-}" 2>/dev/null) ${dim}($(git --git-dir="$REPO" log -1 --format=%cr "${current##*-}" 2>/dev/null))${reset}"
    else
        field  version none
    fi

    # Versions pour rollback, la plus récente d'abord ; l'active en gras
    value=
    while IFS= read -r release; do
        if [[ releases/$release == "$current" ]]; then
            value+="${bold}${release##*-}${reset} "
        else
            value+="${dim}${release##*-}${reset} "
        fi
    done < <(ls -1 "$DATA/releases" 2>/dev/null | sort -r)
    field  available "${value% }"

    if [[ -n $current ]]; then
        value=
        for name in $(enabled); do
            value+="${green}$name${reset} "
        done
        field  packages "${value% }"
        for name in $(packages); do
            if [[ -n $(missing "$name") ]]; then
                skipped+="${yellow}$name${reset} ($(missing "$name" | sed 's/ $//') not installed) "
            fi
        done
        [[ -n $skipped ]] && field  skipped "${skipped% }"
    fi
    field  files "$(wc -l <"$DATA/links" 2>/dev/null || echo 0) links in ~"
    if [[ -f $DATA/last-update ]]; then
        last=$(<"$DATA/last-update")
        # Plus de 2 jours sans mise à jour réussie : en jaune
        if (( $(date +%s) - last > 2 * 86400 )); then
            field  "last update" "${yellow}$(stamp "$last")${reset}"
        else
            field  "last update" "$(stamp "$last")"
        fi
    fi
    if command -v systemctl >/dev/null && systemctl --user is-enabled dotfiles-update.timer >/dev/null 2>&1; then
        next=$(systemctl --user show dotfiles-update.timer -p NextElapseUSecRealtime --value --timestamp=unix)
        [[ $next == @* ]] && field  "next update" "$(stamp "${next#@}")"
    fi
    update_failure
    [[ -n $current ]] && checks
    return 0
}

# Mise à jour automatique en échec (le « ⚠ » de la barre d'état de tmux) :
# l'affiche en rouge avec le dernier message d'erreur de l'installateur
update_failure() {
    command -v systemctl >/dev/null &&
        systemctl --user is-failed --quiet dotfiles-update.service 2>/dev/null || return 0
    local error
    error=$(journalctl --user -u dotfiles-update.service -o cat -n 200 --no-pager 2>/dev/null |
        grep '^dotfiles: ' | tail -n 1)
    error "automatic update failed${error:+: ${error#dotfiles: }}"
    note "details: journalctl --user -u dotfiles-update"
}

usage() {
    local c=$cyan r=$reset d=$dim
    say "${bold}dotfiles${reset}: install and keep the same dotfiles up to date on every machine"
    say ""
    say "  ${c}dotfiles install${r} <repository>  first install; <repository> is a git URL"
    say "                                 ${d}(https://github.com/.../dotfiles.git) or a local path${r}"
    say "  ${c}dotfiles update${r}                fetch the latest commit and apply it"
    say "  ${c}dotfiles switch${r} <branch>       follow another branch (to test it) and install it;"
    say "                                 ${d}\"dotfiles switch master\" to come back${r}"
    say "  ${c}dotfiles rollback${r}              go back to the previous version"
    say "  ${c}dotfiles status${r}                repository, installed version, updates, packages"
}

case ${1:-} in
    install)  shift; cmd_install "$@" ;;
    update)   cmd_update ;;
    switch)   shift; cmd_switch "$@" ;;
    rollback) cmd_rollback ;;
    status)   cmd_status ;;
    *)        usage; exit 1 ;;
esac
