# ---------------------------------------------------------
# RTX 5090 / Blackwell / NvVFX-ready ComfyUI Image
# ---------------------------------------------------------

FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST="12.0" \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

# ---------------------------------------------------------
# System dependencies
# ---------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    git wget curl aria2 ffmpeg rsync \
    build-essential ninja-build pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    libvulkan1 \
    ca-certificates \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.11 python3.11-venv python3.11-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# ---------------------------------------------------------
# Python virtual environment
# ---------------------------------------------------------

RUN python3 -m venv $VIRTUAL_ENV && \
    pip install --upgrade pip setuptools wheel

# ---------------------------------------------------------
# PyTorch Nightly (Blackwell safe, CUDA 12.8)
# ---------------------------------------------------------

RUN pip install --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# ---------------------------------------------------------
# Core Python dependencies
# ---------------------------------------------------------

RUN pip install \
    "numpy<2" pillow scipy tqdm psutil requests pyyaml \
    huggingface_hub safetensors transformers accelerate \
    einops sentencepiece \
    opencv-python kornia spandrel soundfile \
    jupyterlab onnxruntime-gpu \
    GitPython rembg imageio-ffmpeg matplotlib pandas

# ---------------------------------------------------------
# NVIDIA Video Effects Python binding
# ---------------------------------------------------------

RUN pip install nvvfx

# Make sure NVIDIA runtime libs are visible
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# ---------------------------------------------------------
# Pre-build ComfyUI inside image
# ---------------------------------------------------------

RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-build && \
    cd /comfy-build && \
    pip install -r requirements.txt

# ---------------------------------------------------------
# Start script
# ---------------------------------------------------------

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000 8888

CMD ["/start.sh"]
