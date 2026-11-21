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
        echo 'dotfiles: background jobs are running, run "exec bash" to load the new configuration' >&2
        __dotfiles_warned=1
        return 0
    fi
    builtin history -a  # sinon la commande en cours manque à l'historique
    echo 'dotfiles: reloading bash'
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
        echo 'dotfiles: a new configuration is installed, run "exec bash" to load it' >&2
        __dotfiles_warned=1
    fi
    return $status
}
PROMPT_COMMAND+=(__dotfiles_check)
