#!/bin/bash

#SBATCH --nodes=1 # change this if you want more than one node
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --time=20-00:00:00
#SBATCH --mem=600G
#SBATCH --partition=deeplearn
#SBATCH -A punim0478
#SBATCH -q gpgpudeeplearn
#SBATCH --gres=gpu:2   # each node has 4 GPUs
#SBATCH --constraint=dlg5|dlg6


CONDA_BASE="$HOME/miniconda3"
source "$CONDA_BASE/etc/profile.d/conda.sh"

cur_dir=$(pwd)

source ~/cd_starvla

echo "Python location is at $(which python)"

python ${cur_dir}/slurm_script/cnn_mlp_vlm_switch_logic.py
