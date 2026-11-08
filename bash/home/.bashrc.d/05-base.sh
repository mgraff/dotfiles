# Couleurs et alias de base que Fedora définit au niveau du système et pas
# Debian, pour avoir le même comportement partout

[[ $- == *i* ]] || return 0

if [[ -z ${LS_COLORS-} ]] && command -v dircolors >/dev/null; then
    eval "$(dircolors -b)"
fi

alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias l.='ls -d .* --color=auto'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
