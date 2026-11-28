# Recharger la configuration après une mise à jour des dotfiles.
#
# - « dotfiles update / switch / rollback » relance ce shell (exec bash) quand
#   la version installée a changé ; le dossier courant et les variables
#   exportées sont conservés, pas les variables ni fonctions non exportées.
#   Si des tâches tournent en arrière-plan, rien n'est relancé : un message
#   rappelle de le faire.
# - Les autres shells ouverts, et ceux mis à jour par le timer, affichent un
#   rappel à leur prochain prompt.
#
# Un programme ne peut pas modifier le shell qui l'a lancé : d'où cette
# fonction autour de la commande ~/.local/bin/dotfiles.

[[ $- == *i* ]] || return 0

# Messages au même format que l'installateur : $1 = warn (jaune, icône) ou
# note (grisé, en retrait sous la sortie de la commande)
__dotfiles_msg() {
    if [[ -t 2 && -z ${NO_COLOR-} && ${TERM:-dumb} != dumb ]]; then
        case $1 in
            warn) printf '\e[1;33m %s\e[0m\n' "$2" >&2 ;;
            note) printf '\e[2m  › %s\e[0m\n' "$2" >&2 ;;
        esac
    else
        printf 'dotfiles: %s\n' "$2" >&2
    fi
}

__dotfiles_current=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/current
__dotfiles_loaded=$(readlink "$__dotfiles_current" 2>/dev/null)

dotfiles() {
    command dotfiles "$@" || return
    case ${1-} in
        install|update|switch|rollback) ;;
        *) return 0 ;;
    esac
    [[ $(readlink "$__dotfiles_current" 2>/dev/null) != "$__dotfiles_loaded" ]] || return 0
    if [[ -n $(jobs -p) ]]; then
        __dotfiles_msg warn 'background jobs are running, run "exec bash" to load the new configuration'
        __dotfiles_warned=1
        return 0
    fi
    builtin history -a  # sinon la commande en cours manque à l'historique
    __dotfiles_msg note 'reloading bash'
    if shopt -q login_shell; then
        exec bash -l
    else
        exec bash
    fi
}

# Rappel, une seule fois, quand la version a changé depuis l'ouverture du shell
__dotfiles_check() {
    local status=$?
    if [[ -z ${__dotfiles_warned-} && -n $__dotfiles_loaded &&
          $(readlink "$__dotfiles_current" 2>/dev/null) != "$__dotfiles_loaded" ]]; then
        __dotfiles_msg warn 'a new configuration is installed, run "exec bash" to load it'
        __dotfiles_warned=1
    fi
    return $status
}
PROMPT_COMMAND+=(__dotfiles_check)
