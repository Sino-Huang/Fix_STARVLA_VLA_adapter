git submodule add https://github.com/Lifelong-Robot-Learning/LIBERO.git modules/LIBERO
git submodule update --init --recursive



# set up libero env
conda create -n LIBERO python=3.10 -y
conda activate LIBERO


export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
conda install -c conda-forge cmake -y

cd modules/LIBERO
pip install egl_probe --no-cache-dir

pip install -r requirements.txt
pip install torch==1.11.0+cu113 torchvision==0.12.0+cu113 torchaudio==0.11.0 --extra-index-url https://download.pytorch.org/whl/cu113
pip install -e .

pip install tyro matplotlib mediapy websockets msgpack
pip install numpy==1.24.4
pip install rich debugpy

# get datasets, input N 
echo N | python benchmark_scripts/download_libero_datasets.py --use-huggingface
# it will be saved in modules/LIBERO/libero/datasets