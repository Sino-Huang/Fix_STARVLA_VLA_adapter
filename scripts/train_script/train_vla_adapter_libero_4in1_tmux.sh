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

sessname="starvla_vla_adapter_train_libero_4in1"
tmux new-session -d -s "$sessname"
if [[ $? -eq 1 ]]; then
    tmux kill-session -t "$sessname"
    echo "Killed existing tmux session: $sessname"
    sleep 3
    echo "Starting new tmux session: $sessname"
    tmux new-session -d -s "$sessname"
fi

source ~/cd_starvla



# Pane 0:
echo "Starting training pane: $sessname"
pane_training_vla="$sessname:0.0"
tmux select-pane -t "$pane_training_vla" -T "training-libero-4in1"
tmux send-keys -t "$pane_training_vla" "source ~/cd_starvla" Enter
tmux send-keys -t "$pane_training_vla" "source env.sh" Enter

tmux send-keys -t "$pane_training_vla" "bash examples/LIBERO/train_files/run_libero_train_vla_adapter.sh" Enter
echo "Training started in pane: $pane_training_vla"

# open another pane to monitor GPU usage
tmux split-window -h -t "$pane_training_vla"
pane_monitor_gpu=$(tmux display-message -p '#{pane_id}')
tmux select-pane -t "$pane_monitor_gpu" -T "monitor-gpu"
tmux send-keys -t "$pane_monitor_gpu" "source ~/cd_starvla" Enter
tmux send-keys -t "$pane_monitor_gpu" "nvitop" Enter
echo "GPU monitoring started in pane: $pane_monitor_gpu"


# echo instructions to attach to the tmux session
echo -e "To attach to the tmux session, run:\ntmux a -t $sessname"

# if in slurm, need to maintain this script session, we check if we are in slurm by checking if SLURM_JOB_ID is set
if [ -n "$SLURM_JOB_ID" ]; then
    # also check if that tmux session there, if not, we can break 
    while tmux has-session -t "$sessname" 2>/dev/null; do
        python scripts/connect_utils/libero_env_alive_check.py
    done
fi
    
    