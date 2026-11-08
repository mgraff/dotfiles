# Prompt sur deux lignes dans le style de starship :
#
#   ⬢ [toolbox] ~/Documents/projet on  main (REBASING 1/3) [!+?⇡]           1   12s  14:32
#   ❯ _
#
# - conteneur toolbox/distrobox, utilisateur@machine seulement en root ou SSH
# - dossier : 3 derniers niveaux, relatif à la racine du dépôt git
# - git : branche, opération en cours, état
#     = conflit  $ stash  ✘ supprimé  » renommé  ! modifié  + indexé  ? non suivi
#     ⇡ en avance  ⇣ en retard  ⇕ divergé
# - à droite : code de retour si ≠ 0, durée de la commande si elle dépasse 2 s,
#   heure (discrète)
# - « ❯ » vert, ou rouge si la dernière commande a échoué

[[ $- == *i* ]] || return 0

# Couleurs entourées de \001 \002 : readline ne les compte pas dans la largeur
declare -A __prompt_c=(
    [reset]=$'\001\e[0m\002'
    [cyan]=$'\001\e[1;36m\002'
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

# $1 : racine du dépôt git (vide hors dépôt)
__prompt_dir() {
    local top=$1 dir=$PWD
    if [[ -n $top && $top != "$HOME" && ( $PWD == "$top" || $PWD == "$top"/* ) ]]; then
        dir=${top##*/}${PWD#"$top"}
    elif [[ $PWD == "$HOME" || $PWD == "$HOME"/* ]]; then
        dir="~${PWD#"$HOME"}"
    fi
    # Garder les 3 derniers niveaux
    [[ $dir =~ ^.+/([^/]+/[^/]+/[^/]+)$ ]] && dir=${BASH_REMATCH[1]}
    __prompt_line+="${__prompt_c[cyan]}${dir}${__prompt_c[reset]}"
    [[ -w $PWD ]] || __prompt_line+="${__prompt_c[red]} ${__prompt_c[reset]}"
}

# $1 : dossier .git
__prompt_git() {
    local gitdir=$1 line branch oid state flags=
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
        __prompt_line+=" ${__prompt_c[green]}(${oid:0:7})${__prompt_c[reset]}"
    else
        __prompt_line+=" on ${__prompt_c[purple]} ${branch}${__prompt_c[reset]}"
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
    [[ -n $state ]] && __prompt_line+=" ${__prompt_c[yellow]}(${state})${__prompt_c[reset]}"

    flags=$conflicted$stashed$deleted$renamed$modified$staged$untracked
    if (( ahead && behind )); then
        flags+='⇕'
    elif (( ahead )); then
        flags+='⇡'
    elif (( behind )); then
        flags+='⇣'
    fi
    [[ -n $flags ]] && __prompt_line+=" ${__prompt_c[red]}[${flags}]${__prompt_c[reset]}"
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
    __prompt_line=

    [[ -n $__prompt_container ]] &&
        __prompt_line+="${__prompt_c[dimred]}⬢ [${__prompt_container}]${__prompt_c[reset]} "

    if (( EUID == 0 )) || [[ -n $SSH_CONNECTION ]]; then
        if (( EUID == 0 )); then
            __prompt_line+="${__prompt_c[red]}${USER:-$(id -un)}${__prompt_c[reset]}"
        else
            __prompt_line+="${__prompt_c[yellow]}${USER:-$(id -un)}${__prompt_c[reset]}"
        fi
        [[ -n $SSH_CONNECTION ]] &&
            __prompt_line+="@${__prompt_c[dimgreen]}${HOSTNAME%%.*}${__prompt_c[reset]}"
        __prompt_line+=" in "
    fi

    command -v git >/dev/null &&
        mapfile -t git < <(git rev-parse --show-toplevel --absolute-git-dir 2>/dev/null)
    __prompt_dir "${git[0]}"
    (( ${#git[@]} == 2 )) && __prompt_git "${git[1]}"

    # Partie droite : code de retour et durée de la commande précédente
    local right=
    if (( __prompt_exit )); then
        right+="${__prompt_c[red]} ${__prompt_exit}${__prompt_c[reset]}"
        __prompt_char="${__prompt_c[red]}❯${__prompt_c[reset]} "
    else
        __prompt_char="${__prompt_c[green]}❯${__prompt_c[reset]} "
    fi
    if (( s >= 2 )); then
        (( s >= 3600 )) && duration+="$(( s / 3600 ))h"
        (( s >= 60 )) && duration+="$(( s % 3600 / 60 ))m"
        duration+="$(( s % 60 ))s"
        right+="${right:+  }${__prompt_c[yellow]} ${duration}${__prompt_c[reset]}"
    fi

    local now
    printf -v now '%(%H:%M)T' -1
    right+="${right:+  }${__prompt_c[dim]}${now}${__prompt_c[reset]}"

    # Aligner la partie droite sur le bord du terminal (simple espace si trop long)
    if [[ -n $right ]]; then
        local pad=$(( COLUMNS - 1 ))  # dernière colonne libre : évite un retour à la ligne
        __prompt_width "$__prompt_line"; (( pad -= __prompt_w ))
        __prompt_width "$right";         (( pad -= __prompt_w ))
        (( pad < 1 )) && pad=1
        printf -v pad '%*s' "$pad" ''
        __prompt_line+=$pad$right
    fi

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
