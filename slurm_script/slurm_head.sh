#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=50000
#SBATCH --gres=gpu:2
#SBATCH --time=6-00:00:00
#SBATCH --qos=gpua100
#SBATCH --partition=A100
#SBATCH --exclude="node[13,16,19,20]"

# Check if script path argument is provided
if [ -z "$1" ]; then
    echo "Error: No script path provided"
    echo "Usage: sbatch slurm_head.sh <script_path>"
    exit 1
fi

SCRIPT_PATH="$1"

# Check if the script file exists

# Initialize conda
CONDA_BASE="$HOME/miniconda3"
source "$CONDA_BASE/etc/profile.d/conda.sh"

module add git

source ~/cd_starvla

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script file '$SCRIPT_PATH' not found"
    exit 1
fi

# Source environment setup
bash $SCRIPT_PATH

# sbatch slurm_script/slurm_head.sh scripts/eval_script/eval_libero_goal_tmux.sh