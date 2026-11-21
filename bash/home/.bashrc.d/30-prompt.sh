# Prompt sur deux lignes dans le style de starship :
#
#   ⬢ [toolbox] ~/Documents/projet      main (REBASING 1/3) !+?⇡ · 󰡨 app 2/2 ·  1 ·  12s · 14:32
#   ❯ _
#
# À gauche, où l'on est :
# - conteneur toolbox/distrobox, utilisateur@machine seulement en root ou SSH
#   (même après « sudo su - »)
# - dossier : chemin complet, parents grisés, racine du dépôt git en gras ;
#   des dossiers du milieu deviennent « … » seulement si la ligne déborde
# À droite, le contexte, séparé par des « · » :
# - git : branche, opération en cours, état
#     = conflit  $ stash  ✘ supprimé  » renommé  ! modifié  + indexé  ? non suivi
#     ⇡ en avance  ⇣ en retard  ⇕ divergé
# - projet compose : voir 35-compose.sh
# - code de retour si ≠ 0, durée de la commande si elle dépasse 2 s,
#   heure (discrète)
# - « ❯ » vert, ou rouge si la dernière commande a échoué

[[ $- == *i* ]] || return 0

# Couleurs entourées de \001 \002 : readline ne les compte pas dans la largeur
declare -A __prompt_c=(
    [reset]=$'\001\e[0m\002'
    [cyan]=$'\001\e[1;36m\002'
    [bold]=$'\001\e[1m\002'
    [blue]=$'\001\e[1;34m\002'
    [purple]=$'\001\e[1;35m\002'
    [red]=$'\001\e[1;31m\002'
    [dimred]=$'\001\e[1;2;31m\002'
    [green]=$'\001\e[1;32m\002'
    [dimgreen]=$'\001\e[1;2;32m\002'
    [yellow]=$'\001\e[1;33m\002'
    [dim]=$'\001\e[2m\002'
)

__prompt_container=
if [[ -f /run/.containerenv ]]; then
    __prompt_container=$(sed -n 's/^name="\(.*\)"$/\1/p' /run/.containerenv)
    : "${__prompt_container:=container}"
elif [[ -n $CONTAINER_ID ]]; then
    __prompt_container=$CONTAINER_ID
fi

# Session SSH : SSH_CONNECTION disparaît après « sudo su - » ou « sudo -i »,
# on cherche donc aussi sshd parmi les processus parents (une fois, au démarrage)
__prompt_ssh=${SSH_CONNECTION:+1}
if [[ -z $__prompt_ssh ]]; then
    __prompt_pid=$PPID
    while (( __prompt_pid > 1 )) && read -r __prompt_comm 2>/dev/null </proc/$__prompt_pid/comm; do
        if [[ $__prompt_comm == sshd* ]]; then
            __prompt_ssh=1
            break
        fi
        # Ligne « PPid: <pid> » de /proc/<pid>/status
        while read -r __prompt_key __prompt_val; do
            [[ $__prompt_key == PPid: ]] && break
        done </proc/$__prompt_pid/status
        __prompt_pid=$__prompt_val
    done
    unset __prompt_pid __prompt_comm __prompt_key __prompt_val
fi

# Premier élément de PROMPT_COMMAND : récupère le code de retour et la durée,
# puis renvoie le même code pour les éléments suivants (systemd, vte…)
__prompt_status() {
    __prompt_exit=$?
    __prompt_elapsed=0
    if [[ -n $__prompt_start ]]; then
        __prompt_elapsed=$(( (${EPOCHREALTIME//[!0-9]/} - __prompt_start) / 1000000 ))
        unset __prompt_start
    fi
    return $__prompt_exit
}

# Largeur affichée du dossier dans width : éléments de parts, « / », un « … »
# par groupe d'éléments masqués (hide), cadenas. Utilise les variables locales
# de __prompt_dir.
__prompt_dir_width() {
    local k
    width=$(( ${#lock} ? 2 : 0 ))
    for (( k = 0; k < n; k++ )); do
        if [[ -z ${hide[k]} ]]; then
            (( width += (k > 0) + ${#parts[k]} ))
        elif [[ -z ${hide[k-1]} ]]; then
            (( width += 2 ))  # « /… »
        fi
    done
}

# Ajoute le dossier courant à __prompt_line : chemin complet, parents grisés,
# racine du dépôt git en gras, dossier courant en cyan. S'il dépasse $2
# colonnes, des dossiers du milieu sont remplacés par « … », en commençant
# par la gauche ; le début (~ ou /), la racine du dépôt et le dossier courant
# restent toujours visibles.
# $1 : racine du dépôt git (vide hors dépôt)   $2 : largeur disponible
__prompt_dir() {
    local top=$1 avail=$2 path=$PWD lock= root=-1 i n width
    local -a parts hide=()

    [[ -w $PWD ]] || lock="${__prompt_c[red]} ${__prompt_c[reset]}"
    if [[ $PWD == / ]]; then
        __prompt_line+="${__prompt_c[cyan]}/${__prompt_c[reset]}$lock"
        return
    fi

    # « ~/a/b » -> (~ a b) ; « /srv/x » -> ("" srv x)
    [[ $PWD == "$HOME" || $PWD == "$HOME"/* ]] && path="~${PWD#"$HOME"}"
    IFS=/ read -ra parts <<<"$path"
    n=${#parts[@]}

    # Indice de la racine du dépôt (le dépôt qui serait ~ lui-même ne compte pas)
    if [[ -n $top && $top != "$HOME" && ( $PWD == "$top" || $PWD == "$top"/* ) ]]; then
        local rest=${PWD#"$top"} tail=()
        IFS=/ read -ra tail <<<"${rest#/}"
        root=$(( n - 1 - ${#tail[@]} ))
    fi

    __prompt_dir_width
    for (( i = 1; i < n - 1 && width > avail; i++ )); do
        (( i == root )) && continue
        hide[i]=1
        __prompt_dir_width
    done

    local dim=${__prompt_c[dim]} reset=${__prompt_c[reset]} out=
    for (( i = 0; i < n; i++ )); do
        if [[ -n ${hide[i]} ]]; then
            [[ -n ${hide[i-1]} ]] || out+="${dim}/…${reset}"
            continue
        fi
        (( i )) && out+="${dim}/${reset}"
        if (( i == n - 1 )); then
            out+="${__prompt_c[cyan]}${parts[i]}${reset}"
        elif (( i == root )); then
            out+="${__prompt_c[bold]}${parts[i]}${reset}"
        else
            out+="${dim}${parts[i]}${reset}"
        fi
    done
    __prompt_line+=$out$lock
}

# Ajoute le segment git à __prompt_right. $1 : dossier .git
__prompt_git() {
    local gitdir=$1 line branch oid state flags= seg
    local ahead=0 behind=0 conflicted= stashed= deleted= renamed= modified= staged= untracked=

    while IFS= read -r line; do
        case $line in
            '# branch.oid '*)  oid=${line#'# branch.oid '} ;;
            '# branch.head '*) branch=${line#'# branch.head '} ;;
            '# branch.ab '*)
                [[ $line =~ \+([0-9]+)\ -([0-9]+) ]]
                ahead=${BASH_REMATCH[1]} behind=${BASH_REMATCH[2]} ;;
            '# stash '*) stashed='$' ;;
            'u '*) conflicted='=' ;;
            [12]' '*)
                [[ ${line:2:2} == *D* ]] && deleted='✘'
                [[ $line == 2* ]] && renamed='»'
                [[ ${line:3:1} == [MT] ]] && modified='!'
                [[ ${line:2:1} != . ]] && staged='+' ;;
            '? '*) untracked='?' ;;
        esac
    done < <(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch --show-stash 2>/dev/null)

    if [[ $branch == '(detached)' ]]; then
        seg="${__prompt_c[green]}(${oid:0:7})${__prompt_c[reset]}"
    else
        seg="${__prompt_c[purple]} ${branch}${__prompt_c[reset]}"
    fi

    if [[ -d $gitdir/rebase-merge ]]; then
        state="REBASING $(<"$gitdir/rebase-merge/msgnum")/$(<"$gitdir/rebase-merge/end")"
    elif [[ -d $gitdir/rebase-apply ]]; then
        state="REBASING $(<"$gitdir/rebase-apply/next")/$(<"$gitdir/rebase-apply/last")"
    elif [[ -f $gitdir/MERGE_HEAD ]]; then
        state=MERGING
    elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then
        state=CHERRY-PICKING
    elif [[ -f $gitdir/REVERT_HEAD ]]; then
        state=REVERTING
    elif [[ -f $gitdir/BISECT_LOG ]]; then
        state=BISECTING
    fi
    [[ -n $state ]] && seg+=" ${__prompt_c[yellow]}(${state})${__prompt_c[reset]}"

    flags=$conflicted$stashed$deleted$renamed$modified$staged$untracked
    if (( ahead && behind )); then
        flags+='⇕'
    elif (( ahead )); then
        flags+='⇡'
    elif (( behind )); then
        flags+='⇣'
    fi
    [[ -n $flags ]] && seg+=" ${__prompt_c[red]}${flags}${__prompt_c[reset]}"
    __prompt_right+=("$seg")
}

# Largeur affichée de $1 (sans les séquences de couleur \001…\002) dans __prompt_w
__prompt_width() {
    local s=$1
    while [[ $s == *$'\001'* ]]; do
        s=${s%%$'\001'*}${s#*$'\002'}
    done
    __prompt_w=${#s}
}

# Dernier élément de PROMPT_COMMAND : construit les deux lignes du prompt
__prompt_render() {
    local git=() s=$__prompt_elapsed duration=
    __prompt_line= __prompt_right=()

    [[ -n $__prompt_container ]] &&
        __prompt_line+="${__prompt_c[dimred]}⬢ [${__prompt_container}]${__prompt_c[reset]} "

    if (( EUID == 0 )) || [[ -n $__prompt_ssh ]]; then
        if (( EUID == 0 )); then
            __prompt_line+="${__prompt_c[red]}${USER:-$(id -un)}${__prompt_c[reset]}"
        else
            __prompt_line+="${__prompt_c[yellow]}${USER:-$(id -un)}${__prompt_c[reset]}"
        fi
        [[ -n $__prompt_ssh ]] &&
            __prompt_line+="@${__prompt_c[dimgreen]}${HOSTNAME%%.*}${__prompt_c[reset]}"
        __prompt_line+=" "
    fi

    command -v git >/dev/null &&
        mapfile -t git < <(git rev-parse --show-toplevel --absolute-git-dir 2>/dev/null)
    (( ${#git[@]} == 2 )) && __prompt_git "${git[1]}"
    declare -F __prompt_compose >/dev/null && __prompt_compose "${git[0]}"

    # Code de retour et durée de la commande précédente
    if (( __prompt_exit )); then
        __prompt_right+=("${__prompt_c[red]} ${__prompt_exit}${__prompt_c[reset]}")
        __prompt_char="${__prompt_c[red]}❯${__prompt_c[reset]} "
    else
        __prompt_char="${__prompt_c[green]}❯${__prompt_c[reset]} "
    fi
    if (( s >= 2 )); then
        (( s >= 3600 )) && duration+="$(( s / 3600 ))h"
        (( s >= 60 )) && duration+="$(( s % 3600 / 60 ))m"
        duration+="$(( s % 60 ))s"
        __prompt_right+=("${__prompt_c[yellow]} ${duration}${__prompt_c[reset]}")
    fi

    local now
    printf -v now '%(%H:%M)T' -1
    __prompt_right+=("${__prompt_c[dim]}${now}${__prompt_c[reset]}")

    local right=${__prompt_right[0]} part
    for part in "${__prompt_right[@]:1}"; do
        right+=" ${__prompt_c[dim]}·${__prompt_c[reset]} $part"
    done

    # Le dossier prend la place qui reste, la dernière colonne restant libre
    # pour éviter un retour à la ligne, plus un espace avant la partie droite
    local pad=$(( COLUMNS - 1 ))
    __prompt_width "$right"; (( pad -= __prompt_w ))
    __prompt_width "$__prompt_line"
    __prompt_dir "${git[0]}" $(( pad - __prompt_w - 1 ))

    # Aligner la partie droite sur le bord du terminal (simple espace si trop long)
    __prompt_width "$__prompt_line"; (( pad -= __prompt_w ))
    (( pad < 1 )) && pad=1
    printf -v pad '%*s' "$pad" ''
    __prompt_line+=$pad$right

    # Ligne vide avant chaque prompt, sauf le tout premier
    __prompt_nl=${__prompt_drawn:+$'\n'}
    __prompt_drawn=1
}

PROMPT_COMMAND=(__prompt_status "${PROMPT_COMMAND[@]}" __prompt_render)

# Conserver les marques d'intégration au terminal ajoutées par vte.sh
if [[ $PS1 == '\[\e]133;D;'* ]]; then
    PS1='\[\e]133;D;$?\e\\\e]133;A\e\\\]${__prompt_nl}${__prompt_line}\n${__prompt_char}\[\e]133;B\e\\\]'
else
    PS1='${__prompt_nl}${__prompt_line}\n${__prompt_char}'
fi

# Heure de début de chaque commande, notée par PS0 (affiché juste avant
# l'exécution) : l'indice d'un tableau vide est une expression arithmétique,
# évaluée dans le shell courant, et l'ensemble ne produit aucun texte.
# EPOCHREALTIME privé de sa virgule donne des microsecondes (bash ≥ 5.0).
PS0='${__prompt_noop[__prompt_start=${EPOCHREALTIME//[!0-9]/}]}'"${PS0:-}"
