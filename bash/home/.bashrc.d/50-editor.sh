# Édition de la ligne de commande (les autres réglages sont dans ~/.inputrc)

[[ $- == *i* ]] || return 0

# Ctrl-Suppr : efface le mot suivant, un mot s'arrêtant aux espaces et aux « / »
# (pendant de Ctrl-Backspace, unix-filename-rubout).
#   ls |-l -a          → ls |-a
#   cd |/usr/share/doc → cd /|share/doc → cd /|doc → cd /|
# Le texte effacé ne peut pas être recollé avec Ctrl-Y.
__editor_kill_path_word() {
    local before=${READLINE_LINE:0:READLINE_POINT}
    local after=${READLINE_LINE:READLINE_POINT}
    local sep=${after%%[!/[:space:]]*}       # séparateurs sous le curseur : conservés
    after=${after#"$sep"}
    after=${after#"${after%%[/[:space:]]*}"}  # le mot
    after=${after#[/[:space:]]}               # et un séparateur derrière lui
    READLINE_LINE=$before$sep$after
    READLINE_POINT=$(( READLINE_POINT + ${#sep} ))
}
bind -x '"\e[3;5~": __editor_kill_path_word'
