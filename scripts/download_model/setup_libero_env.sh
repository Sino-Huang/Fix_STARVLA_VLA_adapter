git submodule add https://github.com/Lifelong-Robot-Learning/LIBERO.git modules/LIBERO
git submodule update --init --recursive



# set up libero env
conda create -p $PWD/.venv/conda_env/LIBERO python=3.10 -y
conda activate $PWD/.venv/conda_env/LIBERO

# to conda remove env, do `conda env remove -p $PWD/.venv/conda_env/LIBERO`

conda clean --all -y
pip cache purge

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
# conda install -c conda-forge cmake -y # you can do `module add git` in slurm system to get cmake

cd modules/LIBERO
pip install egl_probe --no-cache-dir

pip install -r requirements.txt --cache-dir "../../.cache/pip"
pip install torch==1.11.0+cu113 torchvision==0.12.0+cu113 torchaudio==0.11.0 --extra-index-url https://download.pytorch.org/whl/cu113
pip install -e .

pip install tyro matplotlib mediapy websockets msgpack
pip install numpy==1.24.4
pip install rich debugpy

# get datasets, input N 
echo N | python benchmark_scripts/download_libero_datasets.py --use-huggingface
# it will be saved in modules/LIBERO/libero/datasets

# download training dataset for fine-tuning
mkdir -p ../../playground/Datasets/LEROBOT_LIBERO_DATA

hf download IPEC-COMMUNITY/libero_10_no_noops_1.0.0_lerobot \
  --repo-type dataset \
  --local-dir ../../playground/Datasets/LEROBOT_LIBERO_DATA/libero_10_no_noops_1.0.0_lerobot --max-workers 4


hf download IPEC-COMMUNITY/libero_object_no_noops_1.0.0_lerobot \
  --repo-type dataset \
  --local-dir ../../playground/Datasets/LEROBOT_LIBERO_DATA/libero_object_no_noops_1.0.0_lerobot --max-workers 4


hf download IPEC-COMMUNITY/libero_spatial_no_noops_1.0.0_lerobot \
  --repo-type dataset \
  --local-dir ../../playground/Datasets/LEROBOT_LIBERO_DATA/libero_spatial_no_noops_1.0.0_lerobot --max-workers 4

hf download IPEC-COMMUNITY/libero_goal_no_noops_1.0.0_lerobot \
  --repo-type dataset \
  --local-dir ../../playground/Datasets/LEROBOT_LIBERO_DATA/libero_goal_no_noops_1.0.0_lerobot --max-workers 4
