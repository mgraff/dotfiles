# Alt-A : demander une commande à Claude en langage naturel.
# On tape sa demande sur la ligne de commande (« les 5 plus gros fichiers
# ici »), Alt-A l'envoie à Claude Code (claude -p) et la remplace par la
# commande proposée, à relire avant de la lancer : rien n'est exécuté.
# Ctrl-_ (annuler) revient à la demande.
#
# Envoyé à Claude : la demande, la distribution, le dossier courant et
# l'utilisateur (root ou non). Modèle : celui de Claude Code par défaut,
# ou CLAUDE_SHELL_MODEL (par exemple « haiku », plus rapide).

[[ $- == *i* ]] || return 0

# Sans Claude Code (serveur distant…), Alt-A le dit au lieu de ne rien faire
if ! command -v claude >/dev/null; then
    __claude_command() {
        printf '\n%s\n' 'claude: Claude Code is not installed on this machine' >&2
    }
    bind -x '"\ea": __claude_command'
    return 0
fi

__claude_command() {
    local request=$READLINE_LINE system reply status=1 tmp fd done=0
    local frames=(✢ ✳ ✶ ✻ ✽ ✻ ✶ ✳) i=0 trap_int
    [[ -n ${request//[[:space:]]/} ]] || return 0
    system=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")
    tmp=$(mktemp) || return 0

    # Claude tourne dans une substitution de processus : pas de tâche, donc ni
    # « [1] pid » ni contrôle des tâches à couper. Elle écrit la réponse dans
    # $tmp, puis son code de retour sur $fd quand elle a fini.
    exec {fd}< <(
        claude -p --tools "" --strict-mcp-config --no-session-persistence \
            --effort low ${CLAUDE_SHELL_MODEL:+--model "$CLAUDE_SHELL_MODEL"} \
            --system-prompt 'Translate the request into one bash command for the system described. Reply with the command only: no explanation, no markdown, no code fence. If several commands are needed, join them with && or a pipe. Prefer commands available by default on that system.' \
            "System: $system, bash ${BASH_VERSION%%(*}, user $USER$( ((EUID)) || echo ' (root)'), current directory $PWD. Request: $request" \
            </dev/null >|"$tmp" 2>/dev/null
        echo $?
    )

    # Pendant l'attente, sur la ligne (que bash a effacée) : astérisque orange
    # animé comme dans Claude Code, « Claude », puis la demande en grisé ;
    # curseur masqué. Ctrl-C abandonne proprement.
    trap_int=$(trap -p INT)
    trap 'done=130' INT
    printf '\e[?25l' >&2
    while (( !done )); do
        printf '\r\e[38;5;209m%s\e[0m Claude \e[2m%s\e[0m\e[K' \
            "${frames[i++ % ${#frames[@]}]}" "$request" >&2
        read -r -t 0.12 -u "$fd" status && done=1
    done
    printf '\r\e[K\e[?25h' >&2
    if [[ -n $trap_int ]]; then eval "$trap_int"; else trap - INT; fi
    exec {fd}<&-
    reply=$(sed '/^```/d' "$tmp")  # au cas où la réponse serait dans un bloc de code
    rm -f "$tmp"

    (( done == 130 )) && return 0
    if (( status != 0 )) || [[ -z $reply ]]; then
        printf '%s\n' 'claude: no answer (run "claude" once to check the login)' >&2
        return 0
    fi
    READLINE_LINE=$reply
    READLINE_POINT=${#READLINE_LINE}
}
bind -x '"\ea": __claude_command'
