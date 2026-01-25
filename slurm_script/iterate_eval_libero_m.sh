#!/bin/bash

echo "Best run this in tmux"
# run squeue | grep sukai and see if both node12 and PD (Resources) status exist

while true; do
    node12_count=$(squeue | grep sukaih | grep -c node12)
    pd_count=$(squeue | grep sukaih | grep -c "PD")
    
    if [ "$node12_count" -ge 1 ] && [ "$pd_count" -ge 1 ]; then
        echo "$(date): node12 and PD (Resources) both present"
        sleep 5
    else
        echo "$(date): node12 or PD not found, submitting job..."
        sbatch scripts/eval_script/eval_libero_goal_tmux.sh
    fi
done
