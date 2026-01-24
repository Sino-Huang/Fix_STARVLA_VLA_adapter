#!/bin/bash
star_vla_python=${CONDA_PREFIX}/bin/python

# check if already set your_ckpt env variable, if not, set default value
if [ -z "$your_ckpt" ]; then
    your_ckpt=$PWD/playground/Pretrained_models/Qwen2.5-VL-GR00T-LIBERO-4in1/checkpoints/steps_30000_pytorch_model.pt
    echo "your_ckpt not set, using default: $your_ckpt"
else
    echo "using your_ckpt: $your_ckpt"
fi

# check if alreayd set gpu_id env variable, if not, set default value
if [ -z "$gpu_id" ]; then
    gpu_id=0
    echo "gpu_id not set, using default: $gpu_id"
else
    echo "using gpu_id: $gpu_id"
fi

port=5694
################# star Policy Server ######################

# export DEBUG=true
CUDA_VISIBLE_DEVICES=$gpu_id ${star_vla_python} deployment/model_server/server_policy.py \
    --ckpt_path ${your_ckpt} \
    --port ${port} \
    --use_bf16

# #################################
