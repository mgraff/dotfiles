# Fichiers et dossiers (module directory de Prezto)

[[ $- == *i* ]] || return 0

shopt -s globstar  # ** parcourt les sous-dossiers : ls **/*.py
set -o noclobber   # > n'écrase pas un fichier existant ; >| pour forcer
