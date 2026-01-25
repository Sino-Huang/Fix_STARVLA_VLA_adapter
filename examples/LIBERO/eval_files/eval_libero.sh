#!/bin/bash

# === Please modify the following paths according to your environment ===
export LIBERO_HOME=$PWD/modules/LIBERO
export LIBERO_CONFIG_PATH=${LIBERO_HOME}/libero
export LIBERO_Python=${CONDA_PREFIX}/bin/python
export PYOPENGL_PLATFORM=egl # for headless rendering
export MUJOCO_GL=egl

export PYTHONPATH=$PYTHONPATH:${LIBERO_HOME} # let eval_libero find the LIBERO tools

host="127.0.0.1"
base_port=5694
unnorm_key="franka"

if [ -z "$eval_port" ]; then
    base_port=5694
    echo "Base port not set, using default: 5694"
else
    base_port=$eval_port
fi


# check if already set your_ckpt env variable, if not, set default value
if [ -z "$your_ckpt" ]; then
    your_ckpt=$PWD/playground/Pretrained_models/Qwen2.5-VL-GR00T-LIBERO-4in1/checkpoints/steps_30000_pytorch_model.pt
    echo "your_ckpt not set, using default: $your_ckpt"
else
    echo "using your_ckpt: $your_ckpt"
fi


folder_name=$(echo "$your_ckpt" | awk -F'/' '{print $(NF-2)"_"$(NF-1)"_"$NF}')
# === End of environment variable configuration ===
###########################################################################################

LOG_DIR="logs/$(date +"%Y%m%d_%H%M%S")"
mkdir -p ${LOG_DIR}


task_suite_name=libero_goal
num_trials_per_task=50
video_out_path="results/${task_suite_name}/${folder_name}"


${LIBERO_Python} ./examples/LIBERO/eval_files/eval_libero.py \
    --args.pretrained-path ${your_ckpt} \
    --args.host "$host" \
    --args.port $base_port \
    --args.task-suite-name "$task_suite_name" \
    --args.num-trials-per-task "$num_trials_per_task" \
    --args.video-out-path "$video_out_path"
