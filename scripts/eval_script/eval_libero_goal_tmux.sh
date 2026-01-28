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
#SBATCH --nodelist=node[12]

# Parameter validation with case statement
case $# in
    0)
        eval_port=5694
        policy_gpu_id=0
        train_id="varying_image_gran_libero4in1_qwen_adapter"
        checkpoint_step=20000
        ;;
    1)
        eval_port=$1
        policy_gpu_id=0
        train_id="varying_image_gran_libero4in1_qwen_adapter"
        checkpoint_step=20000
        ;;
    2)
        eval_port=$1
        policy_gpu_id=$2
        train_id="varying_image_gran_libero4in1_qwen_adapter"
        checkpoint_step=20000
        ;;
    3)
        eval_port=$1
        policy_gpu_id=$2
        train_id=$3
        checkpoint_step=20000
        ;;
    *)
        eval_port=$1
        policy_gpu_id=$2
        train_id=$3
        checkpoint_step=$4
        ;;
esac

your_ckpt="$PWD/results/Checkpoints/${train_id}/checkpoints/steps_${checkpoint_step}_pytorch_model.pt"



sessname="eval_libero_port_${eval_port}_step_${checkpoint_step}_gpu_${policy_gpu_id}"
tmux new-session -d -s "$sessname"
if [[ $? -eq 1 ]]; then
    # meaning it already exists
    echo "Tmux session $sessname already exists."
    # Check if panes are free (not running any processes)
    if tmux list-panes -t "$sessname" -F "#{pane_pid}" | while read pid; do
        [ -z "$(ps -p $pid -o comm=)" ] && continue || exit 1
    done; then
        tmux kill-session -t "$sessname"
        echo "Killed existing tmux session: $sessname"
        sleep 1
        echo "Starting new tmux session: $sessname"
        tmux new-session -d -s "$sessname"
    else
        echo "Panes are still running. Skipping session restart."
    fi
    if [ -n "$SLURM_JOB_ID" ]; then
        # also check if that tmux session there, if not, we can break 
        while tmux has-session -t "$sessname" 2>/dev/null; do
            python scripts/connect_utils/libero_env_alive_check.py
        done
    fi
fi

source ~/cd_starvla


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
# export eval_port
tmux send-keys -t "$pane_policy_server" "export eval_port=$eval_port" Enter

# do kill -9 $(lsof -t -i :$eval_port)  # kill previous process on that port if any
tmux send-keys -t "$pane_policy_server" "kill \$(lsof -t -i :$eval_port)" Enter

tmux send-keys -t "$pane_policy_server" "bash examples/LIBERO/eval_files/run_policy_server.sh" Enter
echo "Policy server started in pane: $pane_policy_server"
sleep 3
# Pane 1:
echo "Starting libero eval in tmux session: $sessname"
# check if libero-env already exists
if tmux list-panes -t "$sessname" | grep -q "libero-env"; then
    echo "Pane libero-env already exists. Skipping creation."
    pane_libero_env=$(tmux list-panes -t "$sessname" -F "#{pane_id} #{pane_title}" | grep "libero-env" | awk '{print $1}')
else
    tmux split-window -v -t "$pane_policy_server"
    pane_libero_env=$(tmux display-message -p '#{pane_id}')
fi

tmux select-pane -t "$pane_libero_env" -T "libero-env"
tmux send-keys -t "$pane_libero_env" "source ~/cd_libero ; cd .. ; cd .." Enter
tmux send-keys -t "$pane_libero_env" "source env.sh" Enter
# export your_ckpt
tmux send-keys -t "$pane_libero_env" "export your_ckpt=$your_ckpt" Enter
# export eval_port
tmux send-keys -t "$pane_libero_env" "export eval_port=$eval_port" Enter

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
    
    