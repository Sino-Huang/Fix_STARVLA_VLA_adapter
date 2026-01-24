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

CONDA_BASE="$HOME/miniconda3"
source "$CONDA_BASE/etc/profile.d/conda.sh"

cur_dir=$(pwd)

source ~/cd_starvla

echo "Python location is at $(which python)"

python ${cur_dir}/slurm_script/cnn_mlp_vlm_switch_logic.py
