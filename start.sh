#!/bin/bash
set -e

source /opt/venv/bin/activate

WORKDIR=/workspace
COMFY_DIR=/workspace/ComfyUI
COMFY_BUILD=/comfy-build
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

mkdir -p "$WORKDIR" "$WORKDIR/input" "$WORKDIR/output" "$WORKDIR/temp"
chmod -R 777 "$WORKDIR" || true

if [ ! -f "$COMFY_DIR/main.py" ]; then
  mkdir -p "$COMFY_DIR"
  rsync -a "$COMFY_BUILD"/ "$COMFY_DIR"/
fi
chmod -R 777 "$COMFY_DIR" || true

# SageAttention (важно для LTX / transformer-heavy)
if ! python -c "import sageattention" 2>/dev/null; then
  rm -rf /tmp/SageAttention
  git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention
  cd /tmp/SageAttention
  pip install . --no-build-isolation || true
  cd "$COMFY_DIR"
fi

mkdir -p "$CUSTOM_NODES"
chmod -R 777 "$CUSTOM_NODES" || true

install_node() {
  local repo="$1"
  local name="$2"

  cd "$CUSTOM_NODES"
  if [ ! -d "$name" ]; then
    git clone "$repo" "$name" || true
  fi

  if [ -f "$CUSTOM_NODES/$name/requirements.txt" ]; then
    cd "$CUSTOM_NODES/$name"
    pip install --no-cache-dir -r requirements.txt || true
  fi

  cd "$COMFY_DIR"
}

# Manager
install_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"

# Workflow nodes
install_node "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "comfyui_controlnet_aux"
install_node "https://github.com/kijai/ComfyUI-LTXVideo.git" "ComfyUI-LTXVideo"
install_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_node "https://github.com/ClownsharkBatwing/RES4LYF.git" "RES4LYF"
install_node "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI.git" "Nvidia_RTX_Nodes_ComfyUI"

mkdir -p "$COMFY_DIR/models/checkpoints" \
         "$COMFY_DIR/models/diffusion_models" \
         "$COMFY_DIR/models/text_encoders" \
         "$COMFY_DIR/models/vae" \
         "$COMFY_DIR/models/loras"
chmod -R 777 "$COMFY_DIR/models" || true

download_model() {
  local url="$1"
  local dest="$2"
  local file="$3"

  if [ -s "$dest/$file" ]; then
    return
  fi

  aria2c -x 8 -s 8 -k 1M -d "$dest" -o "$file" "$url" || \
  wget -O "$dest/$file" "$url"
}

# Checkpoints
download_model "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors" "$COMFY_DIR/models/checkpoints" "ltx-2.3-22b-dev-fp8.safetensors"
download_model "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors" "$COMFY_DIR/models/checkpoints" "ltx-2.3-22b-distilled-fp8.safetensors"

# Diffusion
download_model "https://huggingface.co/black-forest-labs/FLUX.2-klein-9b-kv-fp8/resolve/main/flux-2-klein-9b-kv-fp8.safetensors" "$COMFY_DIR/models/diffusion_models" "flux-2-klein-9b-kv-fp8.safetensors"

# Text encoders
download_model "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" "$COMFY_DIR/models/text_encoders" "gemma_3_12B_it_fp4_mixed.safetensors"
download_model "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" "$COMFY_DIR/models/text_encoders" "qwen_3_8b_fp8mixed.safetensors"

# LoRA
download_model "https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors" "$COMFY_DIR/models/loras" "ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"

# VAE
download_model "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors" "$COMFY_DIR/models/vae" "flux2-vae.safetensors"

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

cd "$COMFY_DIR"
python main.py --listen 0.0.0.0 --port 3000 --gpu-only
