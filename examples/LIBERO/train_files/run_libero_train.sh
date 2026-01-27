device_name=$(cat /etc/hostname | tr -d '\n')
# if fitcluster, then we are on monash nlp cluster
if [[ "$device_name" == *"fitcluster"* ]] || [[ "$device_name" == *"node"* ]]; then
    unset NCCL_IB_HCA
    unset NCCL_SOCKET_IFNAME
    # used for check save when communication
    export NCCL_BLOCKING_WAIT=1
    export NCCL_ASYNC_ERROR_HANDLING=1
    export NCCL_TIMEOUT=10000  # timeout set to 1 hour (unit: seconds)
    export NCCL_SOCKET_TIMEOUT_MS=360000
    export NCCL_SOCKET_IFNAME=ens193  # ! important for deepspeed multi node
    export NCCL_IB_DISABLE=0
    export TORCH_CUDA_ARCH_LIST="8.0;8.6+PTX"
    echo "Running on FitCluster, variable set"
elif [[ "$device_name" == *"spartan"* ]] ; then 
    export NCCL_SOCKET_IFNAME=bond0.3027  # ! important for deepspeed multi node
    export TORCH_CUDA_ARCH_LIST="8.0;8.6+PTX"
    export CC=/usr/bin/gcc
    export CXX=/usr/bin/g++
    export NCCL_IB_DISABLE=0
    export NCCL_BLOCKING_WAIT=1
    export NCCL_ASYNC_ERROR_HANDLING=1
    export NCCL_TIMEOUT=10000  # timeout set to 1 hour (unit: seconds)
    export NCCL_SOCKET_TIMEOUT_MS=360000
    echo "Running on Spartan Server, variable set"
elif [[ "$device_name" == *"darpa"* ]] || [[ "$device_name" == *"ansr-5090"* ]]; then
    # 5090 * 4 single server with no infiniband
    unset NCCL_IB_HCA
    unset NCCL_SOCKET_IFNAME
    export NCCL_IB_DISABLE=1
    echo "Running on Darpa Server, variable set"

else
    echo "This script is only for fitcluster or darpa device. Current device: ${device_name}"
    exit 1  
fi

###########################################################################################
# === Please modify the following paths according to your environment ===
Framework_name=QwenOFT
freeze_module_list='qwen_vl_interface.model.model.language_model'
base_vlm=playground/Pretrained_models/Qwen3-VL-4B-Instruct
config_yaml=./examples/LIBERO/train_files/starvla_cotrain_libero.yaml
libero_data_root=playground/Datasets/LEROBOT_LIBERO_DATA
data_mix=libero_all
run_root_dir=./results/Checkpoints
run_id=varying_image_gran_libero4in1_qwen3oft
varying_image_resolution=true
# === End of environment variable configuration ===
###########################################################################################


# export WANDB_MODE=disabled

output_dir=${run_root_dir}/${run_id}
mkdir -p ${output_dir}
# mv this script to the output dir
cp $0 ${output_dir}/

# check number of GPUs from CUDA_VISIBLE_DEVICES
if [ -z "$CUDA_VISIBLE_DEVICES" ]; then
    echo "CUDA_VISIBLE_DEVICES is not set. Using all available GPUs."
    TOTAL_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
else
    IFS=',' read -r -a gpu_array <<< "$CUDA_VISIBLE_DEVICES"
    TOTAL_GPUS=${#gpu_array[@]}
fi
echo "Total GPUs to be used for training: $TOTAL_GPUS"
# set num_processes based on TOTAL_GPUS
num_processes=$TOTAL_GPUS
# if num_processes == 2, set per_device_batch_size to 16, if num_processes ==4, set per_device_batch_size to 8
if [ "$num_processes" -eq 2 ]; then
    per_device_batch_size=16
    gradient_accumulation_steps=2
elif [ "$num_processes" -eq 4 ]; then
    per_device_batch_size=8
    gradient_accumulation_steps=2
else
    per_device_batch_size=8
    gradient_accumulation_steps=2
fi

accelerate launch \
  --config_file starVLA/config/deepseeds/deepspeed_zero2.yaml \
  --num_processes ${num_processes} \
  starVLA/training/train_starvla.py \
  --config_yaml ${config_yaml} \
  --framework.name ${Framework_name} \
  --framework.qwenvl.base_vlm ${base_vlm} \
  --datasets.vla_data.data_root_dir ${libero_data_root}\
  --datasets.vla_data.data_mix ${data_mix} \
  --datasets.vla_data.per_device_batch_size ${per_device_batch_size} \
  --trainer.vla_data.video_backend torchvision_av \
  --datasets.vla_data.varying_image_resolution $varying_image_resolution \
  --datasets.vla_data.track_image_sizes $varying_image_resolution \
  --trainer.freeze_modules ${freeze_module_list} \
  --trainer.max_train_steps 45000 \
  --trainer.save_interval 3000 \
  --trainer.logging_frequency 100 \
  --trainer.eval_interval 100 \
  --trainer.gradient_accumulation_steps ${gradient_accumulation_steps} \
  --run_root_dir ${run_root_dir} \
  --run_id ${run_id} \
  --wandb_project starvla_vanilla_libero \
  --wandb_entity sukai-huang-monash-university \
  # --is_debug True



##### Multi-Server Multi-GPU training script #####
  # accelerate launch \
  #   --config_file starVLA/config/deepseeds/deepspeed_zero2.yaml \
  #   --main_process_ip $MASTER_ADDR \
  #   --main_process_port $MASTER_PORT \
  #   --machine_rank $SLURM_PROCID \
  #   --num_machines $SLURM_NNODES \
  #   --num_processes=${TOTAL_GPUS} \
  #   starVLA/training/train_starvla.py \
  #   --config_yaml ${config_yaml} \
  #   --framework.name ${Framework_name} \
  #   --framework.qwenvl.base_vlm ${base_vlm} \
  #   --run_root_dir ${run_root_dir} \
  #   --run_id ${run_id} \
  #   --wandb_project your_project \
  #   --wandb_entity your_name
##### Multi-Server Multi-GPU training script #####
