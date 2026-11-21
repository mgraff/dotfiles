# Segment « compose » du prompt (appelé par 30-prompt.sh) quand le dossier
# courant, ou un parent, contient un fichier compose :
#
#   ~/monapp on  main  via 󰡨 monapp 3/3
#   ~/monapp on  main  via 󰡨 monapp 2/3 (db ✘)
#   ~/monapp on  main  via 󰡨 monapp 3/3 ✚ api ↻ worker ⟳
#
# - nom du projet, services en marche / services déclarés
#   (vert : tous, jaune : une partie, gris : aucun)
# - services arrêtés, quand une partie seulement tourne
# - ✚ healthcheck en échec   ↻ redémarre en boucle
# - ⟳ fichier compose ou .env modifié après la création des conteneurs
#
# La recherche du fichier s'arrête à la racine du dépôt git, sinon à $HOME.
# L'état des conteneurs (docker, ou podman s'il n'en voit aucun) est gardé 10 s,
# et relu après chaque commande qui mentionne compose, podman ou docker.

[[ $- == *i* ]] || return 0

__compose_ttl=10
declare -A __compose_svc=()

# Cherche un fichier compose de $PWD jusqu'à $1 (racine git), $HOME ou /.
# Résultat dans __compose_files : le fichier principal, puis l'override éventuel.
__compose_find() {
    local stop=$1 dir=$PWD f
    __compose_files=()
    while :; do
        for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
            [[ -f $dir/$f ]] || continue
            __compose_files=("$dir/$f")
            for f in compose.override.yaml compose.override.yml \
                     docker-compose.override.yaml docker-compose.override.yml; do
                [[ -f $dir/$f ]] && __compose_files+=("$dir/$f")
            done
            return 0
        done
        [[ -z $dir || $dir == "$stop" || $dir == "$HOME" ]] && return 1
        dir=${dir%/*}
    done
}

# Lecture sommaire du YAML (sans yq) : nom du projet et services.
# __compose_svc[service]=1 s'il démarre par défaut, 0 s'il dépend d'un profil
# inactif ; __compose_order garde l'ordre de déclaration.
__compose_parse() {
    local file line indent val p svc= svc_indent= child_indent= in_services= in_profiles=
    local -A active=()
    for p in ${__compose_profiles//,/ }; do active[$p]=1; done

    for file in "${__compose_files[@]}"; do
        in_services= svc=
        while IFS= read -r line || [[ -n $line ]]; do
            line=${line%$'\r'}
            [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
            [[ $line =~ ^[[:space:]]* ]]
            indent=${#BASH_REMATCH[0]}

            if (( indent == 0 )); then
                in_services= svc= in_profiles=
                if [[ $line == services:* ]]; then
                    in_services=1 svc_indent=
                elif [[ -z $__compose_yaml_name && $line =~ ^name:[[:space:]]*[\"\']?([^\"\'#[:space:]]+) ]]; then
                    __compose_yaml_name=${BASH_REMATCH[1]}
                fi
                continue
            fi
            [[ -n $in_services ]] || continue

            # Éléments de « profiles: » écrits en liste, un par ligne
            if [[ -n $in_profiles ]] && (( indent >= child_indent )) &&
                [[ $line =~ ^[[:space:]]*-[[:space:]]*[\"\']?([^\"\'#[:space:]]+) ]]; then
                [[ -n ${active[${BASH_REMATCH[1]}]} ]] && __compose_svc[$svc]=1
                continue
            fi
            in_profiles=

            : "${svc_indent:=$indent}"
            if (( indent == svc_indent )); then
                if [[ $line =~ ^[[:space:]]*[\"\']?([A-Za-z0-9._-]+)[\"\']?[[:space:]]*: ]]; then
                    svc=${BASH_REMATCH[1]} child_indent=
                    if [[ ! -v __compose_svc[$svc] ]]; then
                        __compose_svc[$svc]=1
                        __compose_order+=("$svc")
                    fi
                fi
                continue
            fi
            [[ -n $svc ]] || continue

            : "${child_indent:=$indent}"
            if (( indent == child_indent )) && [[ $line =~ ^[[:space:]]*profiles:[[:space:]]*(.*)$ ]]; then
                __compose_svc[$svc]=0
                val=${BASH_REMATCH[1]}
                if [[ $val == \[* ]]; then
                    val=${val#[}
                    val=${val%%]*}
                    for p in ${val//[\"\',]/ }; do
                        [[ -n ${active[$p]} ]] && __compose_svc[$svc]=1
                    done
                else
                    in_profiles=1
                fi
            fi
        done < "$file"
    done
}

# Conteneurs du projet, une ligne par conteneur :
# service|état|statut|redémarrages|création (epoch, 0 si inconnue)
# docker d'abord ; podman si docker n'en connaît aucun (les deux peuvent être
# installés sur la même machine)
__compose_ps() {
    local filter="label=com.docker.compose.project=$__compose_name" i
    local -a lines created
    if command -v docker >/dev/null; then
        # docker ne donne ni le nombre de redémarrages ni une date en epoch :
        # « 2026-11-20 10:06:00 +0100 CET », convertie en un seul appel à date
        mapfile -t lines < <(docker ps -a --filter "$filter" \
            --format '{{.Label "com.docker.compose.service"}}|{{.State}}|{{.Status}}|0|{{.CreatedAt}}')
        if (( ${#lines[@]} )); then
            mapfile -t created < <(printf '%s\n' "${lines[@]##*|}" | sed 's/ [A-Za-z]*$//' | date -f - +%s)
            for i in "${!lines[@]}"; do
                printf '%s|%s\n' "${lines[i]%|*}" "${created[i]:-0}"
            done
            return
        fi
    fi
    command -v podman >/dev/null || return 0
    podman ps -a --filter "$filter" \
        --format '{{.Label "com.docker.compose.service"}}|{{.State}}|{{.Status}}|{{.Restarts}}|{{.Created.Unix}}'
} 2>/dev/null

# Recalcule __compose_seg pour le projet de __compose_files
__compose_refresh() {
    local dir=${__compose_files[0]%/*} line key val svc state status restarts created
    local env_name=${COMPOSE_PROJECT_NAME-} newest=0 mtime=0 up=0 total=0 color
    local -a ps stopped=() problems=()
    local -A running=() unhealthy=() looping=()
    __compose_profiles=${COMPOSE_PROFILES-}
    __compose_svc=() __compose_order=() __compose_yaml_name= __compose_seg=

    # Le .env du projet compte comme l'environnement, qui reste prioritaire
    if [[ -f $dir/.env ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
            [[ $line =~ ^(export[[:space:]]+)?(COMPOSE_PROJECT_NAME|COMPOSE_PROFILES)=[\"\']?([^\"\'#[:space:]]*) ]] || continue
            key=${BASH_REMATCH[2]} val=${BASH_REMATCH[3]}
            if [[ $key == COMPOSE_PROJECT_NAME ]]; then
                [[ -v COMPOSE_PROJECT_NAME ]] || env_name=$val
            else
                [[ -v COMPOSE_PROFILES ]] || __compose_profiles=$val
            fi
        done < "$dir/.env"
    fi

    __compose_parse

    # Même règle que compose : variable, puis « name: », puis nom du dossier,
    # réduit aux caractères a-z 0-9 _ -
    __compose_name=${env_name:-${__compose_yaml_name:-${dir##*/}}}
    __compose_name=${__compose_name,,}
    __compose_name=${__compose_name//[^-_a-z0-9]/}

    __compose_seg=" via ${__prompt_c[blue]}󰡨 ${__compose_name}${__prompt_c[reset]}"

    command -v podman >/dev/null || command -v docker >/dev/null || return 0
    mapfile -t ps < <(__compose_ps)

    for line in "${ps[@]}"; do
        IFS='|' read -r svc state status restarts created <<<"$line"
        [[ -n $svc ]] || continue
        (( created > newest )) && newest=$created
        # En boucle : « restarting » (docker), ou plusieurs redémarrages et
        # le conteneur est arrêté ou vient de repartir (podman)
        if [[ $state == restarting ]] ||
            { (( restarts >= 2 )) && [[ $state != running || $status == *second* ]]; }; then
            looping[$svc]=1
        fi
        if [[ $state == running ]]; then
            running[$svc]=1
            [[ $status == *'(unhealthy)'* ]] && unhealthy[$svc]=1
        fi
    done

    # Les services hors profil actif ne comptent que s'ils tournent quand même
    for svc in "${__compose_order[@]}"; do
        if [[ -n ${running[$svc]} ]]; then
            (( ++total, ++up ))
        elif (( __compose_svc[$svc] )); then
            (( ++total ))
            [[ -n ${looping[$svc]} ]] || stopped+=("$svc")
        fi
        [[ -n ${unhealthy[$svc]} ]] && problems+=("✚ $svc")
        [[ -n ${looping[$svc]} ]] && problems+=("↻ $svc")
    done

    if (( up && up == total )); then
        color=${__prompt_c[green]}
    elif (( up )); then
        color=${__prompt_c[yellow]}
    else
        color=${__prompt_c[dim]}
    fi
    __compose_seg+=" ${color}${up}/${total}${__prompt_c[reset]}"

    # Noms des services arrêtés, seulement si d'autres tournent (3 au plus)
    if (( up && ${#stopped[@]} )); then
        val="${stopped[*]:0:3}"
        (( ${#stopped[@]} > 3 )) && val+=" …"
        __compose_seg+=" ${__prompt_c[red]}(${val} ✘)${__prompt_c[reset]}"
    fi
    (( ${#problems[@]} )) && __compose_seg+=" ${__prompt_c[red]}${problems[*]}${__prompt_c[reset]}"

    # Fichiers modifiés depuis la création du conteneur le plus récent
    if (( newest )); then
        while read -r val; do
            (( val > mtime )) && mtime=$val
        done < <(stat -c %Y "${__compose_files[@]}" "$dir/.env" 2>/dev/null)
        (( mtime > newest )) && __compose_seg+=" ${__prompt_c[yellow]}⟳${__prompt_c[reset]}"
    fi
}

# Ajoute le segment à __prompt_line. $1 : racine du dépôt git (vide hors dépôt)
__prompt_compose() {
    __compose_find "$1" || return 0

    # Relire l'état après une commande qui a pu changer les conteneurs
    local last
    last=$(HISTTIMEFORMAT= builtin history 1)
    if [[ $last != "$__compose_last" ]]; then
        [[ $last =~ compose|podman|docker ]] && __compose_time=0
        __compose_last=$last
    fi

    if [[ ${__compose_files[*]} != "$__compose_key" ]] ||
        (( EPOCHSECONDS - ${__compose_time:-0} >= __compose_ttl )); then
        __compose_key=${__compose_files[*]}
        __compose_time=$EPOCHSECONDS
        __compose_refresh
    fi
    __prompt_line+=$__compose_seg
}
