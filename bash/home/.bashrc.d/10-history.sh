# Historique : grand, horodaté, sans doublons, comme INC_APPEND_HISTORY de
# zsh. Chaque commande est ajoutée au fichier dès son lancement, mais chaque
# shell ne relit pas le fichier : il ne voit que l'historique présent à son
# ouverture, plus ses propres commandes. Les shells ouverts ensuite voient
# tout. À la fermeture, le fichier est dédoublonné.

[[ $- == *i* ]] || return 0

HISTSIZE=10000       # commandes en mémoire
HISTFILESIZE=20000   # lignes du fichier : 2 par commande (horodatage, commande)
HISTTIMEFORMAT='%F %T '        # horodatage enregistré dans le fichier
HISTCONTROL=ignoreboth:erasedups  # ni doublons, ni commandes commençant par un espace

shopt -s histappend  # en quittant, ajouter au fichier au lieu de l'écraser
shopt -s histverify  # afficher le résultat de !!, !$… avant de l'exécuter
shopt -s cmdhist     # une commande sur plusieurs lignes = une seule entrée

# Ajouter la dernière commande au fichier, sans relire celles des autres shells
__history_append() {
    local status=$?
    builtin history -a
    return $status
}
PROMPT_COMMAND+=(__history_append)

# À la fermeture (exit, Ctrl-D, terminal ou pane fermé) : ne garder dans le
# fichier que la dernière occurrence de chaque commande, avec son horodatage.
# Fichier réécrit à côté puis renommé, sous verrou entre shells. Un « source »
# d'un script qui pose son propre trap EXIT remplace celui-ci : le fichier
# garde alors ses doublons jusqu'à la fermeture d'un autre shell.
__history_dedup() {
    local file=${HISTFILE:-$HOME/.bash_history}
    [[ -f $file && ! -L $file && -w ${file%/*} ]] || return 0
    (
        flock -w 1 9 || exit 0
        tmp=$(mktemp "$file.XXXXXX") || exit 0
        # Une entrée = « #horodatage » puis la commande (une ou plusieurs
        # lignes) ; avant le premier horodatage, une ligne = une entrée
        if awk '
            /^#[0-9]+$/ { n++; ts[n] = $0; timed = 1; next }
            timed && (n in cmd) { cmd[n] = cmd[n] "\n" $0; next }
            timed { cmd[n] = $0; next }
            { n++; cmd[n] = $0 }
            END {
                for (i = 1; i <= n; i++) if (i in cmd) last[cmd[i]] = i
                for (i = 1; i <= n; i++)
                    if ((i in cmd) && last[cmd[i]] == i) {
                        if (i in ts) print ts[i]
                        print cmd[i]
                    }
            }' "$file" >|"$tmp" && [[ -s $tmp ]]; then
            mv -f -- "$tmp" "$file"
        else
            rm -f -- "$tmp"
        fi
    ) 9>>"${XDG_RUNTIME_DIR:-/tmp}/bash-history-$UID.lock"
}
trap __history_dedup EXIT

# Commandes les plus utilisées
history-stat() {
    HISTTIMEFORMAT= builtin history |
        awk '{ print $2 }' | sort | uniq -c | sort -rn | head -n "${1:-20}"
}
