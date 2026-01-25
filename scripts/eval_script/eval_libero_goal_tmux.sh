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

sessname="starvla_eval_libero_goal"
tmux new-session -d -s "$sessname"
if [[ $? -eq 1 ]]; then
    tmux kill-session -t "$sessname"
    echo "Killed existing tmux session: $sessname"
    sleep 3
    echo "Starting new tmux session: $sessname"
    tmux new-session -d -s "$sessname"
fi

source ~/cd_starvla

your_ckpt=$PWD/results/Checkpoints/1229_libero4in1_qwen3oft/checkpoints/steps_20000_pytorch_model.pt


policy_gpu_id=0

# Pane 0:
echo "Starting policy server in tmux session: $sessname"
pane_policy_server="$sessname:0.0"
tmux select-pane -t "$pane_policy_server" -T "policy-server"
tmux send-keys -t "$pane_policy_server" "source ~/cd_starvla" Enter
tmux send-keys -t "$pane_policy_server" "source env.sh" Enter
# export your_ckpt
tmux send-keys -t "$pane_policy_server" "export your_ckpt=$your_ckpt" Enter
# export GPU id for policy server
tmux send-keys -t "$pane_policy_server" "export gpu_id=$policy_gpu_id" Enter

tmux send-keys -t "$pane_policy_server" "bash examples/LIBERO/eval_files/run_policy_server.sh" Enter
echo "Policy server started in pane: $pane_policy_server"
sleep 3
# Pane 1:
echo "Starting libero eval in tmux session: $sessname"
tmux split-window -v -t "$pane_policy_server"
pane_libero_env=$(tmux display-message -p '#{pane_id}')
tmux select-pane -t "$pane_libero_env" -T "libero-env"
tmux send-keys -t "$pane_libero_env" "source ~/cd_libero ; cd .. ; cd .." Enter
tmux send-keys -t "$pane_libero_env" "source env.sh" Enter
# export your_ckpt
tmux send-keys -t "$pane_libero_env" "export your_ckpt=$your_ckpt" Enter

# remove previous process on port 10092
tmux send-keys -t "$pane_libero_env" "kill $(lsof -t -i :10092)" Enter

tmux send-keys -t "$pane_libero_env" "bash examples/LIBERO/eval_files/eval_libero.sh" Enter
echo "Libero eval started in pane: $pane_libero_env"

# echo instructions to attach to the tmux session
echo -e "To attach to the tmux session, run:\ntmux a -t $sessname"

# if in slurm, need to maintain this script session, we check if we are in slurm by checking if SLURM_JOB_ID is set
if [ -n "$SLURM_JOB_ID" ]; then
    # also check if that tmux session there, if not, we can break 
    while tmux has-session -t "$sessname" 2>/dev/null; do
        python scripts/connect_utils/libero_env_alive_check.py
    done
fi
    
    