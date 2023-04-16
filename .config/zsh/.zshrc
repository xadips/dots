fpath+=($ZDOTDIR/plugins $fpath)

# +------------+
# | NAVIGATION |
# +------------+

setopt AUTO_CD # Go to folder path without using cd.

setopt AUTO_PUSHD        # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS # Do not store duplicates in the stack.
setopt PUSHD_SILENT      # Do not print the directory stack after pushd or popd.

setopt CORRECT       # Spelling correction
setopt CDABLE_VARS   # Change directory to a path stored in a variable.
setopt EXTENDED_GLOB # Use extended globbing syntax.

# +---------+
# | HISTORY |
# +---------+

setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.

# +--------+
# | COLORS |
# +--------+

# Override colors
eval "$(dircolors -b $ZDOTDIR/dircolors)"

# +--------+
# | PROMPT |
# +--------+

fpath=($ZDOTDIR/prompt $fpath)
autoload -Uz prompt_purification_setup
prompt_purification_setup

plugins=()

# +---------+
# | SCRIPTS |
# +---------+

eval $(keychain --agents 'ssh,gpg' --eval --quiet --noask id_rsa C30D3E7D1257494C)

# +------------+
# | COMPLETION |
# +------------+

autoload -U compinit
compinit
_comp_options+=(globdots) # With hidden files
source $ZDOTDIR/plugins/completion.zsh

# +-----+
# | VIM |
# +-----+

# Vi mode
bindkey -v
export KEYTIMEOUT=1

# Change cursor
autoload -Uz cursor_mode
cursor_mode

# Use vim keys in tab complete menu
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# edit current command line with vim (vim-mode, then v)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# +---------+
# | ALIASES |
# +---------+

source $HOME/.config/aliases

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
