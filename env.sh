export CUDA_HOME=$CONDA_PREFIX
export PYTHONPATH=$PWD
export WORKING_DIR=$PWD
export HF_HOME=$PWD/.cache/hf
export TRITON_CACHE_DIR=$PWD/.cache/triton
# export NCCL_SOCKET_IFNAME=bond0.3027 # for unimelb


device_name=$(cat /etc/hostname | tr -d '\n') # fitcluster or node*

# if spartan, set NCCL_SOCKET_IFNAME
if [[ "$device_name" == *"spartan"* ]]; then
    export NCCL_SOCKET_IFNAME=bond0
else
    unset NCCL_SOCKET_IFNAME
fi

if [[ "$device_name" == *"fitcluster"* ]] || [[ "$device_name" == *"spartan"* ]]; then
    export CUDA_VISIBLE_DEVICES=0,1 # only 2 GPUs on fit cluster
elif [[ "$device_name" == *"node"* ]]; then
    export CUDA_VISIBLE_DEVICES=0,1 # all 4 GPUs on unimelb node12
elif [[ "$device_name" == *"darpa"* ]] || [[ "$device_name" == *"ansr-5090"* ]]; then
    export CUDA_VISIBLE_DEVICES=0,1,2,3 # all 4 GPUs on darpa server
else
    echo "This script is only for fitcluster or darpa device. Current device: ${device_name}"
    exit 1  
fi
