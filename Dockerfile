# RTX 5090 / Blackwell / Video-oriented
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST="12.0" \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev \
    git wget curl aria2 ffmpeg ca-certificates rsync \
    build-essential ninja-build pkg-config \
    libgl1-mesa-glx libglib2.0-0 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

RUN python3 -m venv $VIRTUAL_ENV && \
    pip install --upgrade pip setuptools wheel

# Torch Nightly for CUDA 12.8 (Blackwell safe path)
RUN pip install --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

RUN pip install \
    "numpy<2" pillow scipy tqdm psutil requests pyyaml \
    safetensors transformers accelerate einops sentencepiece \
    opencv-python kornia spandrel soundfile \
    onnxruntime-gpu jupyterlab matplotlib pandas \
    huggingface_hub

# ComfyUI build
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-build && \
    cd /comfy-build && \
    pip install -r requirements.txt

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000 8888
CMD ["/start.sh"]
