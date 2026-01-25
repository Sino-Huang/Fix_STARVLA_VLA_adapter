# Created by `pipx` on 2026-01-23 12:25:59
export PATH="$PATH:/home/sukaih/.local/bin"
# User specific aliases and functions
module add gcc
module add git
module add slurm

# fnm
FNM_PATH="/home/sukaih/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
. "$HOME/.cargo/env"

# GoLang
export GOROOT=/home/sukaih/.go
export PATH=$GOROOT/bin:$PATH
export GOPATH=/home/sukaih/go
export PATH=$GOPATH/bin:$PATH

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

export PATH="/home/sukaih/.pixi/bin:$PATH"
eval "$(zoxide init bash)"

# opencode
export PATH=/home/sukaih/.opencode/bin:$PATH

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/sukaih/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/sukaih/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/sukaih/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/sukaih/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
