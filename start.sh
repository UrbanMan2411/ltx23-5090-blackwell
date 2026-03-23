#!/bin/bash
set -e

source /opt/venv/bin/activate

WORKDIR=/workspace
COMFY_DIR=/workspace/ComfyUI
COMFY_BUILD=/comfy-build
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

echo "Preparing workspace..."

mkdir -p "$WORKDIR" "$WORKDIR/input" "$WORKDIR/output" "$WORKDIR/temp"
chmod -R 777 "$WORKDIR" || true

# Restore ComfyUI into /workspace if missing
if [ ! -f "$COMFY_DIR/main.py" ]; then
  mkdir -p "$COMFY_DIR"
  rsync -a "$COMFY_BUILD"/ "$COMFY_DIR"/
fi

chmod -R 777 "$COMFY_DIR" || true

mkdir -p "$CUSTOM_NODES"
chmod -R 777 "$CUSTOM_NODES" || true

install_custom_node() {
  local repo_url="$1"
  local folder_name="$2"

  cd "$CUSTOM_NODES"

  if [ ! -d "$folder_name" ]; then
    echo "Installing $folder_name ..."
    git clone "$repo_url" "$folder_name" || true
  fi

  if [ -f "$CUSTOM_NODES/$folder_name/requirements.txt" ]; then
    cd "$CUSTOM_NODES/$folder_name"
    pip install --no-cache-dir -r requirements.txt || true
  fi

  cd "$COMFY_DIR"
}

echo "Installing custom nodes..."

install_custom_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
install_custom_node "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "comfyui_controlnet_aux"
install_custom_node "https://github.com/Lightricks/ComfyUI-LTXVideo.git" "ComfyUI-LTXVideo"
install_custom_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
install_custom_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_custom_node "https://github.com/ClownsharkBatwing/RES4LYF.git" "RES4LYF"
install_custom_node "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI.git" "ComfyUI_NVIDIA_RTX_Nodes"
install_custom_node "https://github.com/kijai/ComfyUI-KJNodes.git" "comfyui-kjnodes"

echo "Applying ONNX GPU fix..."

pip uninstall -y onnxruntime onnxruntime-gpu || true
pip install --no-deps --force-reinstall onnxruntime-gpu==1.24.3 || true

echo "Preparing model folders..."

mkdir -p "$COMFY_DIR/models/checkpoints" \
         "$COMFY_DIR/models/diffusion_models" \
         "$COMFY_DIR/models/vae" \
         "$COMFY_DIR/models/text_encoders" \
         "$COMFY_DIR/models/clip_vision" \
         "$COMFY_DIR/models/detection" \
         "$COMFY_DIR/models/loras"

chmod -R 777 "$COMFY_DIR/models" || true

echo "Downloading models if missing..."

download_if_missing() {
  local url="$1"
  local output_path="$2"

  if [ ! -f "$output_path" ]; then
    echo "Downloading $(basename "$output_path")..."
    aria2c -x 16 -s 16 -k 1M -d "$(dirname "$output_path")" -o "$(basename "$output_path")" "$url"
  else
    echo "$(basename "$output_path") already exists, skipping."
  fi
}

# --- LTX Checkpoints ---
download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-distilled-fp8.safetensors?download=true" \
"$COMFY_DIR/models/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors"

download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors?download=true" \
"$COMFY_DIR/models/checkpoints/ltx-2.3-22b-dev-fp8.safetensors"

# --- FLUX diffusion model ---
download_if_missing \
"https://huggingface.co/black-forest-labs/FLUX.2-klein-9b-kv-fp8/resolve/main/flux-2-klein-9b-kv-fp8.safetensors" \
"$COMFY_DIR/models/diffusion_models/flux-2-klein-9b-kv-fp8.safetensors"

# --- Text Encoders ---
download_if_missing \
"https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" \
"$COMFY_DIR/models/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors"

download_if_missing \
"https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
"$COMFY_DIR/models/text_encoders/qwen_3_8b_fp8mixed.safetensors"

# --- LoRA ---
download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors" \
"$COMFY_DIR/models/loras/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"

# --- VAE ---
download_if_missing \
"https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors" \
"$COMFY_DIR/models/vae/flux2-vae.safetensors"

# CUDA allocator tuning for 5090
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128

echo "Starting Jupyter..."

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

echo "Starting ComfyUI..."

cd "$COMFY_DIR"

python main.py \
  --listen 0.0.0.0 \
  --port 3000 \
  --lowvram \
  --enable-manager
