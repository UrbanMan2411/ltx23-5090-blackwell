#!/bin/bash
set -e

source /opt/venv/bin/activate

WORKDIR=/workspace
COMFY_RUNTIME=/workspace/ComfyUI
COMFY_BUILD=/comfy-build
CUSTOM_NODES="$COMFY_RUNTIME/custom_nodes"

mkdir -p "$WORKDIR" "$WORKDIR/input" "$WORKDIR/output" "$WORKDIR/temp"
chmod -R 777 "$WORKDIR" || true

# Restore ComfyUI into /workspace
if [ ! -f "$COMFY_RUNTIME/main.py" ]; then
  mkdir -p "$COMFY_RUNTIME"
  rsync -a "$COMFY_BUILD"/ "$COMFY_RUNTIME"/
fi
chmod -R 777 "$COMFY_RUNTIME" || true

cd "$COMFY_RUNTIME"

# =========================
# Install SageAttention (needed for LTX)
# =========================
if ! python -c "import sageattention" 2>/dev/null; then
  rm -rf /tmp/SageAttention
  git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention
  cd /tmp/SageAttention
  pip install . --no-build-isolation || true
  cd "$COMFY_RUNTIME"
fi

# =========================
# Custom Nodes
# =========================

mkdir -p "$CUSTOM_NODES"
chmod -R 777 "$CUSTOM_NODES" || true

install_custom_node() {
  local repo_url="$1"
  local folder_name="$2"

  cd "$CUSTOM_NODES"
  if [ ! -d "$folder_name" ]; then
    git clone "$repo_url" "$folder_name" || true
  fi

  if [ -f "$CUSTOM_NODES/$folder_name/requirements.txt" ]; then
    cd "$CUSTOM_NODES/$folder_name"
    pip install --no-cache-dir -r requirements.txt || true
  fi

  cd "$COMFY_RUNTIME"
}

install_custom_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
install_custom_node "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "comfyui_controlnet_aux"
install_custom_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_custom_node "https://github.com/kijai/ComfyUI-LTXVideo.git" "ComfyUI-LTXVideo"
install_custom_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
install_custom_node "https://github.com/RES4LYF/RES4LYF.git" "RES4LYF"
install_custom_node "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI.git" "ComfyUI_NVIDIA_RTX_Nodes"

# =========================
# Model Folders
# =========================

mkdir -p models/checkpoints \
         models/loras \
         models/vae \
         models/text_encoders \
         models/diffusion_models

chmod -R 777 models || true

download_if_missing() {
  local url="$1"
  local dest="$2"
  local name="$3"

  if [ ! -s "$dest/$name" ]; then
    aria2c -x 8 -s 8 -k 1M -d "$dest" -o "$name" "$url"
  fi
}

# =========================
# LTX 2.3 22B MODELS
# =========================

download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors?download=true" \
"$COMFY_RUNTIME/models/checkpoints" \
"ltx-2.3-22b-dev-fp8.safetensors"

download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors?download=true" \
"$COMFY_RUNTIME/models/checkpoints" \
"ltx-2.3-22b-distilled-fp8.safetensors"

# =========================
# TEXT ENCODERS
# =========================

download_if_missing \
"https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" \
"$COMFY_RUNTIME/models/text_encoders" \
"gemma_3_12B_it_fp4_mixed.safetensors"

download_if_missing \
"https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
"$COMFY_RUNTIME/models/text_encoders" \
"qwen_3_8b_fp8mixed.safetensors"

# =========================
# VAE
# =========================

download_if_missing \
"https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors" \
"$COMFY_RUNTIME/models/vae" \
"flux2-vae.safetensors"

# =========================
# LORA
# =========================

download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors" \
"$COMFY_RUNTIME/models/loras" \
"ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"

# =========================
# Jupyter (RunPod proxy safe)
# =========================

jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_origin='*' \
  --ServerApp.disable_check_xsrf=True \
  --ServerApp.root_dir=/workspace \
  > /workspace/jupyter.log 2>&1 &

# =========================
# Launch ComfyUI
# =========================
# IMPORTANT: never import torch before this

python main.py --listen 0.0.0.0 --port 3000 --gpu-only
