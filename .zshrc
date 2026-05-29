# greeter
[[ $SHLVL -eq 1 ]] && fastfetch

# vcs
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' formats ' %b'
zstyle ':vcs_info:git:*' unstagedstr ' ⚠'
zstyle ':vcs_info:git:*' stagedstr ' ⚠'

export VIRTUAL_ENV_DISABLE_PROMPT=1
setopt PROMPT_SUBST

function _nerv_precmd {
  vcs_info

  # venv
  local venv_seg=""
  [[ $VIRTUAL_ENV ]] && venv_seg="%F{#ffbf00}($(basename $VIRTUAL_ENV))%f "

  # ssh
  local ssh_seg=""
  [[ -n $SSH_CONNECTION ]] && ssh_seg="%F{#ff4444}󱎤󱎤󰫵%f "

  # git
  local git_seg=""
  [[ -n $vcs_info_msg_0_ ]] && git_seg="%F{#cc0000}${vcs_info_msg_0_}%f "

  # box color priority: root > ssh > dirty git > failed exit > venv > default
  local bc="%F{#cc0000}"
  [[ $VIRTUAL_ENV ]]        && bc="%F{#ffbf00}"
  [[ -n $vcs_info_msg_0_ && $(git status --short 2>/dev/null) ]] && bc="%F{#ff4444}"
  [[ -n $SSH_CONNECTION ]]  && bc="%F{#ff4444}"
  [[ $UID -eq 0 ]]          && bc="%F{#ff4444}"

  # user
  local user_seg="%F{#cc0000}%n%f"
  [[ $UID -eq 0 ]] && user_seg="%F{#ff4444}MAGI-ROOT%f"

  # print top line
  print -P "${bc}╭%f${venv_seg}${ssh_seg}${user_seg}%F{#444444}@%f%F{#cc0000}%m%f %F{#ffbf00}%~%f ${git_seg}"

  # set bottom line color — %(?..) checks last exit code
  PROMPT="${bc}╰>>%f %(?.. %F{#ff4444}[%?]%f )"
  PROMPT_IS_READY=1
}

[[ ! -v PROMPT_IS_READY ]] && precmd_functions+=(_nerv_precmd)

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#660000"

# path update
export PATH="$HOME/.local/bin:$PATH"

# aliases
alias grep='grep --color=auto'
alias cls=clear
alias ls='ls --color=auto'
alias sa='source ~/.zshrc; echo "ZSH aliases sourced."'
alias mconf='west build -t menuconfig'

# keybinds
bindkey "^[[H"  beginning-of-line
bindkey "^[[F"  end-of-line
bindkey "^[[1~" beginning-of-line   # Home under tmux-256color
bindkey "^[[4~" end-of-line         # End under tmux-256color
bindkey "^[[3~" delete-char

# direnv hook
eval "$(direnv hook zsh)"

# atuin — MUST BE LAST
eval "$(atuin init zsh)"
