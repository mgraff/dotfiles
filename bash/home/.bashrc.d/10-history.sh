# Historique : grand, horodaté, sans doublons. Chaque shell ne voit que
# l'historique du fichier à son ouverture, plus ses propres commandes ; il
# ajoute ses commandes au fichier en se fermant (exit, Ctrl-D, terminal ou
# pane fermé), et les shells ouverts ensuite les retrouvent. Un « exec » perd
# les commandes du shell remplacé, sauf « dotfiles update » qui les enregistre.

[[ $- == *i* ]] || return 0

HISTSIZE=10000
HISTFILESIZE=10000
HISTTIMEFORMAT='%F %T '        # horodatage enregistré dans le fichier
HISTCONTROL=ignoreboth:erasedups  # ni doublons, ni commandes commençant par un espace

shopt -s histappend  # en quittant, ajouter au fichier au lieu de l'écraser
shopt -s histverify  # afficher le résultat de !!, !$… avant de l'exécuter
shopt -s cmdhist     # une commande sur plusieurs lignes = une seule entrée

# Commandes les plus utilisées
history-stat() {
    HISTTIMEFORMAT= builtin history |
        awk '{ print $2 }' | sort | uniq -c | sort -rn | head -n "${1:-20}"
}
