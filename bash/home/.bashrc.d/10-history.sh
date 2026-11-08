# Historique, comme le module history de Prezto :
# grand, horodaté, sans doublons et partagé entre tous les terminaux ouverts.

[[ $- == *i* ]] || return 0

HISTSIZE=10000
HISTFILESIZE=10000
HISTTIMEFORMAT='%F %T '        # horodatage enregistré dans le fichier
HISTCONTROL=ignoreboth:erasedups  # ni doublons, ni commandes commençant par un espace

shopt -s histappend  # ajouter au fichier au lieu de l'écraser en quittant
shopt -s histverify  # afficher le résultat de !!, !$… avant de l'exécuter
shopt -s cmdhist     # une commande sur plusieurs lignes = une seule entrée

# Partage : à chaque prompt, enregistrer la dernière commande dans le fichier
# puis recharger le fichier pour voir celles des autres terminaux.
__history_sync() {
    builtin history -a
    builtin history -c
    builtin history -r
}
PROMPT_COMMAND+=(__history_sync)

# Commandes les plus utilisées
history-stat() {
    HISTTIMEFORMAT= builtin history |
        awk '{ print $2 }' | sort | uniq -c | sort -rn | head -n "${1:-20}"
}
