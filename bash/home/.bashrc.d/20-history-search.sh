# Recherche dans l'historique avec ↑/↓ à partir du texte déjà tapé,
# comme le module history-substring-search de Prezto :
# correspondance sur une sous-chaîne, insensible à la casse, sans doublons.

[[ $- == *i* ]] || return 0

__hss_reset() {
    unset __hss_last
    __hss_query=
    __hss_index=-1
    __hss_matches=()
}

# $1 : 1 pour remonter vers les commandes plus anciennes, -1 pour redescendre
__hss_move() {
    # Nouvelle recherche si la ligne a été modifiée depuis le dernier résultat
    if [[ ! -v __hss_last || $READLINE_LINE != "$__hss_last" ]]; then
        __hss_query=$READLINE_LINE
        __hss_index=-1
        # Récupérer les commandes lancées entre-temps dans les autres terminaux
        declare -F __history_sync >/dev/null && __history_sync
        mapfile -t __hss_matches < <(
            HISTTIMEFORMAT= builtin history |
                sed -E 's/^ *[0-9]+\*? *//' |
                awk -v q="$__hss_query" '
                    { lines[NR] = $0 }
                    END {
                        q = tolower(q)
                        for (i = NR; i > 0; i--)
                            if ((q == "" || index(tolower(lines[i]), q)) && !seen[lines[i]]++)
                                print lines[i]
                    }'
        )
    fi

    local i=$(( __hss_index + $1 ))
    (( i < ${#__hss_matches[@]} )) || return 0  # plus ancien résultat atteint
    if (( i < 0 )); then
        # Redescendu au-delà du plus récent : on retrouve le texte tapé
        i=-1
        READLINE_LINE=$__hss_query
    else
        READLINE_LINE=${__hss_matches[i]}
    fi
    __hss_index=$i
    __hss_last=$READLINE_LINE
    READLINE_POINT=${#READLINE_LINE}
}

__hss_reset
PROMPT_COMMAND+=(__hss_reset)

# Flèches en mode normal (\e[) et en mode application (\eO) du terminal
bind -x '"\e[A": __hss_move 1'
bind -x '"\eOA": __hss_move 1'
bind -x '"\e[B": __hss_move -1'
bind -x '"\eOB": __hss_move -1'
