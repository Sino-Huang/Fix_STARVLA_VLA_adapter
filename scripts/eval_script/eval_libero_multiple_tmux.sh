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
        train_id="varying_image_gran_libero4in1_qwen_adapter"
        available_gpus="0,1"
        max_parallel=2
        start_port=5694
        ;;
    1)
        train_id=$1
        available_gpus="0,1"
        max_parallel=2
        start_port=5694
        ;;
    2)
        train_id=$1
        available_gpus=$2
        max_parallel=2
        start_port=5694
        ;;
    3)
        train_id=$1
        available_gpus=$2
        max_parallel=$3
        start_port=5694
        ;;
    *)
        train_id=$1
        available_gpus=$2
        max_parallel=$3
        start_port=$4
        ;;
esac

checkpoint_folder="$PWD/results/Checkpoints/${train_id}/checkpoints"

# Check if checkpoint folder exists
if [ ! -d "$checkpoint_folder" ]; then
    echo "Error: Checkpoint folder not found: $checkpoint_folder"
    exit 1
fi

# Convert available_gpus string to array
IFS=',' read -ra GPU_ARRAY <<< "$available_gpus"
num_gpus=${#GPU_ARRAY[@]}

echo "=== Evaluation Configuration ==="
echo "Train ID: $train_id"
echo "Checkpoint folder: $checkpoint_folder"
echo "Available GPUs: ${GPU_ARRAY[@]}"
echo "Max parallel jobs: $max_parallel"
echo "Starting port: $start_port"
echo "================================"

# Get list of checkpoint steps (sorted numerically)
checkpoint_steps=()
for ckpt_file in "$checkpoint_folder"/steps_*_pytorch_model.pt; do
    if [ -f "$ckpt_file" ]; then
        # Extract step number from filename
        step=$(basename "$ckpt_file" | sed 's/steps_\([0-9]*\)_pytorch_model.pt/\1/')
        checkpoint_steps+=("$step")
    fi
done

# Sort checkpoint steps numerically
IFS=$'\n' checkpoint_steps=($(sort -n <<<"${checkpoint_steps[*]}"))
unset IFS

if [ ${#checkpoint_steps[@]} -eq 0 ]; then
    echo "Error: No checkpoint files found in $checkpoint_folder"
    exit 1
fi

echo "Found ${#checkpoint_steps[@]} checkpoints: ${checkpoint_steps[@]}"
echo ""

# Function to count active evaluation tmux sessions for this train_id
count_active_sessions() {
    tmux list-sessions 2>/dev/null | grep -c "eval_libero_port_.*_step_.*_gpu_" || echo "0"
}

# Function to check if a specific session is still running
is_session_running() {
    local session_name=$1
    tmux has-session -t "$session_name" 2>/dev/null
    return $?
}

# Track running jobs
declare -A running_jobs  # session_name -> checkpoint_step
job_index=0
gpu_index=0
port_offset=0

# Process all checkpoints
for step in "${checkpoint_steps[@]}"; do
    # Wait if we've reached max parallel jobs
    while [ $(count_active_sessions) -ge $max_parallel ]; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Max parallel jobs ($max_parallel) reached. Waiting for a slot..."
        sleep 30
        
        # Clean up completed jobs from tracking
        for session_name in "${!running_jobs[@]}"; do
            if ! is_session_running "$session_name"; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Job completed: $session_name (step ${running_jobs[$session_name]})"
                unset running_jobs["$session_name"]
            fi
        done
    done
    
    # Assign GPU (round-robin)
    gpu_id=${GPU_ARRAY[$gpu_index]}
    gpu_index=$(( (gpu_index + 1) % num_gpus ))
    
    # Assign port (increment to avoid conflicts)
    eval_port=$((start_port + port_offset))
    port_offset=$((port_offset + 1))
    
    # Generate session name
    session_name="eval_libero_port_${eval_port}_step_${step}_gpu_${gpu_id}"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting evaluation:"
    echo "  Checkpoint step: $step"
    echo "  GPU ID: $gpu_id"
    echo "  Port: $eval_port"
    echo "  Session: $session_name"
    
    # Launch the single evaluation script in background
    # Unset TMUX variable to allow creating tmux sessions from within tmux
    TMUX= bash "$PWD/scripts/eval_script/eval_libero_single_tmux.sh" \
        "$eval_port" \
        "$gpu_id" \
        "$train_id" \
        "$step" &
    
    # Track this job
    running_jobs["$session_name"]="$step"
    
    # Give it a moment to initialize
    sleep 5
    
    echo ""
done

# Wait for all remaining jobs to complete
echo "$(date '+%Y-%m-%d %H:%M:%S') - All checkpoints launched. Waiting for completion..."
while [ $(count_active_sessions) -gt 0 ]; do
    active_count=$(count_active_sessions)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Still running: $active_count sessions"
    
    # Clean up completed jobs from tracking
    for session_name in "${!running_jobs[@]}"; do
        if ! is_session_running "$session_name"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Job completed: $session_name (step ${running_jobs[$session_name]})"
            unset running_jobs["$session_name"]
        fi
    done
    
    sleep 30
done

echo "$(date '+%Y-%m-%d %H:%M:%S') - All evaluations completed!"
echo "Results location: $PWD/results/"
    

# bash scripts/eval_script/eval_libero_multiple_tmux.sh varying_image_gran_libero4in1_qwen_adapter "0,1,2,3" 4 6001 
