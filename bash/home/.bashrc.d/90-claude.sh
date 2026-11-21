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
    local request=$READLINE_LINE system reply
    [[ -n ${request//[[:space:]]/} ]] || return 0
    system=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")
    printf '\e[2m%s\e[0m' ' claude…' >&2
    reply=$(claude -p --tools "" --strict-mcp-config --no-session-persistence \
        --effort low ${CLAUDE_SHELL_MODEL:+--model "$CLAUDE_SHELL_MODEL"} \
        --system-prompt 'Translate the request into one bash command for the system described. Reply with the command only: no explanation, no markdown, no code fence. If several commands are needed, join them with && or a pipe. Prefer commands available by default on that system.' \
        "System: $system, bash ${BASH_VERSION%%(*}, user $USER$( ((EUID)) || echo ' (root)'), current directory $PWD. Request: $request" \
        </dev/null 2>/dev/null)
    local status=$?
    # Efface « claude… » (le curseur est resté à sa fin)
    printf '\e[%dD\e[K' 8 >&2
    # Au cas où la réponse serait entourée d'un bloc de code
    reply=$(sed '/^```/d' <<<"$reply")
    if (( status != 0 )) || [[ -z $reply ]]; then
        printf '\n%s\n' 'claude: no answer (run "claude" once to check the login)' >&2
        return 0
    fi
    READLINE_LINE=$reply
    READLINE_POINT=${#READLINE_LINE}
}
bind -x '"\ea": __claude_command'
