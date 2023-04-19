export PATH=$HOME/bin:/local/bin:/home/spidax/.local/bin:$PATH
# XDG

export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CACHE_HOME=$HOME/.cache
export XDG_SCREENSHOTS_DIR=$HOME/Pictures/screenshots

# editor

export EDITOR="vim"
export VISUAL="vim"
export GRIMBLAST_EDITOR=imv
export PARU_CONF=$XDG_CONFIG_HOME/paru/paru.conf
# Proton
export STEAM_COMPAT_DATA_PATH=$HOME/proton
export STEAM_ROOT="/home/spidax/.local/share/Steam"
# zsh

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$ZDOTDIR/.zhistory" # History filepath
export HISTSIZE=10000                # Maximum events for internal history
export SAVEHIST=10000                # Maximum events in history file

export GPG_TTY=$(tty)
