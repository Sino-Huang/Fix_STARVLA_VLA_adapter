export CUDA_HOME=$CONDA_PREFIX
export PYTHONPATH=$PWD
export WORKING_DIR=$PWD
export HF_HOME=$PWD/.cache/hf
export TRITON_CACHE_DIR=$PWD/.cache/triton
export CUDA_VISIBLE_DEVICES=0,1,2,3
# export NCCL_SOCKET_IFNAME=bond0.3027 # for unimelb