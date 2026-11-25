# 1Password : shell plugins du CLI (gh, glab, aws…), qui s'authentifient via
# l'application au lieu d'un jeton en clair. ~/.config/op/plugins.sh est créé
# par « op plugin init <outil> » ; la complétion de op est générée par le hook
# du paquet bash.

[[ $- == *i* ]] || return 0
command -v op >/dev/null || return 0
[[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/op/plugins.sh ]] || return 0
. "${XDG_CONFIG_HOME:-$HOME/.config}/op/plugins.sh"
