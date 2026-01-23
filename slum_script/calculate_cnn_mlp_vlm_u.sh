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


cur_dir=$(pwd)

source ~/cd_vla.sh

cd ~

python ${cur_dir}/cnn_mlp_vlm_switch_logic.py
