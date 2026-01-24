#!/bin/bash
sessname="starvla_eval_libero_goal"
tmux new-session -d -s "$sessname"
if [[ $? -eq 1 ]]; then
    tmux kill-session -t "$sessname"
    echo "Killed existing tmux session: $sessname"
    sleep 3
    echo "Starting new tmux session: $sessname"
    tmux new-session -d -s "$sessname"
fi

your_ckpt=$PWD/playground/Pretrained_models/Qwen2.5-VL-GR00T-LIBERO-4in1/checkpoints/steps_30000_pytorch_model.pt

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
tmux send-keys -t "$pane_libero_env" "bash examples/LIBERO/eval_files/eval_libero.sh" Enter
echo "Libero eval started in pane: $pane_libero_env"

# echo instructions to attach to the tmux session
echo -e "To attach to the tmux session, run:\ntmux a -t $sessname"