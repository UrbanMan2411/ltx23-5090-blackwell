#!/bin/bash
set -e

source /opt/venv/bin/activate

WORKDIR=/workspace
COMFY_RUNTIME=/workspace/ComfyUI
COMFY_CACHE=/comfy-build

mkdir -p "$WORKDIR" "$WORKDIR/models"
chmod -R 777 "$WORKDIR" || true

if [ ! -f "$COMFY_RUNTIME/main.py" ]; then
  mkdir -p "$COMFY_RUNTIME"
  rsync -a "$COMFY_CACHE"/ "$COMFY_RUNTIME"/
fi

cd "$COMFY_RUNTIME"

mkdir -p models/checkpoints \
         models/loras \
         models/vae \
         models/text_encoders

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
"https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors" \
"$COMFY_RUNTIME/models/vae" \
"flux2-vae.safetensors"

# =========================
# LORA
# =========================

download_if_missing \
"https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors" \
"$COMFY_RUNTIME/models/loras" \
"ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors"

# Jupyter (RunPod proxy safe)
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

# IMPORTANT: no early torch import before this line
python main.py --listen 0.0.0.0 --port 3000 --disable-auto-launch
