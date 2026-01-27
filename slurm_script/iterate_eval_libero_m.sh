#!/bin/bash

echo "Best run this in tmux"
node_name=$1
# run squeue | grep sukai and see if both node12 and PD (Resources) status exist

# if node_name is empty, exit
if [ -z "$node_name" ]; then
    echo "Please provide the node name as the first argument."
    exit 1
fi

while true; do
    node_count=$(squeue | grep sukaih | grep -c "${node_name}")
    pd_count=$(squeue | grep sukaih | grep -c "PD")
    
    if [ "$node_count" -ge 1 ] && [ "$pd_count" -ge 1 ]; then
        echo "$(date): ${node_name} and PD (Resources) both present"
        sleep 5
    else
        echo "$(date): ${node_name} or PD not found, submitting job..."
        sbatch scripts/eval_script/eval_libero_goal_tmux.sh
        sleep 5
    fi
done
