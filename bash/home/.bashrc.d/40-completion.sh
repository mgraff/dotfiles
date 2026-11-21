# Complétion (les réglages de Tab sont dans ~/.inputrc ; les scripts de
# complétion de kubectl, npm, pip… sont générés par le hook du paquet bash)

[[ $- == *i* ]] || return 0

shopt -s no_empty_cmd_completion  # Tab sur une ligne vide ne liste pas toutes les commandes

# La complétion floue de fzf (**<Tab>) est chargée par 25-fzf.sh
