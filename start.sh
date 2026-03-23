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

# Restore ComfyUI into /workspace
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

install_custom_node "https://github.com/Comfy-Org/ComfyUI-Manager.git" "ComfyUI-Manager"
install_custom_node "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "comfyui_controlnet_aux"
install_custom_node "https://github.com/Lightricks/ComfyUI-LTXVideo.git" "ComfyUI-LTXVideo"
install_custom_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
install_custom_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
install_custom_node "https://github.com/ClownsharkBatwing/RES4LYF.git" "RES4LYF"
install_custom_node "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI.git" "ComfyUI_NVIDIA_RTX_Nodes"

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

# Critical allocator tweak for 5090
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

echo "Starting ComfyUI (5090 optimized)..."

cd "$COMFY_DIR"

python main.py \
  --listen 0.0.0.0 \
  --port 3000 \
  --gpu-only \
  --lowvram
