FROM runpod/worker-comfyui:5.8.4-base

USER root

# 1. Ensure system packages are present
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    g++ \
    python3-dev \
    libgl1 \
    libglx-mesa0 \
    libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 📦 Fix: Use the container's native python3 executable to run pip modules globally
RUN python3 -m pip install --no-cache-dir onnxruntime-gpu transformers

# 🛑 Fix: Symlink the expected paths so custom node scripts don't break later
RUN mkdir -p /opt/venv/bin && \
    ln -sf /usr/bin/python3 /opt/venv/bin/python3 && \
    ln -sf /usr/bin/python3 /opt/venv/bin/python && \
    ln -sf $(which pip3 || echo "/usr/local/bin/pip3") /opt/venv/bin/pip3 && \
    ln -sf $(which pip3 || echo "/usr/local/bin/pip3") /opt/venv/bin/pip

# ⚡ Global ONNX and Package setup

# 2. IAMCCS custom nodes installed globally
RUN git clone https://github.com/IAMCCS/IAMCCS-nodes /comfyui/custom_nodes/IAMCCS-nodes && \
    if [ -f /comfyui/custom_nodes/IAMCCS-nodes/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /comfyui/custom_nodes/IAMCCS-nodes/requirements.txt; \
    fi



# 4. Core WanVideo Wrapper (Handles SVI via LoRA weights)
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper /comfyui/custom_nodes/ComfyUI-WanVideoWrapper && \
    if [ -f /comfyui/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-WanVideoWrapper/requirements.txt; \
    fi

# 5. Utility nodes (pinned commits for reproducibility)
RUN git clone https://github.com/kijai/ComfyUI-KJNodes /comfyui/custom_nodes/ComfyUI-KJNodes \
    && cd /comfyui/custom_nodes/ComfyUI-KJNodes \
    && (git checkout 79f529a84a8c20fe5dcdfa984c6be7a94102c014 2>/dev/null || \
        (git fetch origin 79f529a84a8c20fe5dcdfa984c6be7a94102c014 --depth=1 \
         && git checkout 79f529a84a8c20fe5dcdfa984c6be7a94102c014) || \
        echo "WARN: falling back to default branch HEAD")

RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite /comfyui/custom_nodes/ComfyUI-VideoHelperSuite \
    && cd /comfyui/custom_nodes/ComfyUI-VideoHelperSuite \
    && (git checkout 8550981384301e9bc5bfea83e5c2c75258102593 2>/dev/null || \
        (git fetch origin 8550981384301e9bc5bfea83e5c2c75258102593 --depth=1 \
         && git checkout 8550981384301e9bc5bfea83e5c2c75258102593) || \
        echo "WARN: falling back to default branch HEAD")

RUN git clone https://github.com/theUpsider/ComfyUI-Logic.git /comfyui/custom_nodes/ComfyUI-Logic

RUN if [ -f /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt; fi
RUN if [ -f /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt; fi
RUN if [ -f /comfyui/custom_nodes/ComfyUI-Logic/requirements.txt ]; then \
        pip3 install --no-cache-dir -r /comfyui/custom_nodes/ComfyUI-Logic/requirements.txt; fi
# Download models into comfyui
RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' --relative-path models/loras --filename 'wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22_Lightx2v/Wan_2_2_I2V_A14B_HIGH_lightx2v_4step_lora_v1030_rank_64_bf16.safetensors' --relative-path models/loras --filename 'Wan_2_2_I2V_A14B_HIGH_lightx2v_4step_lora_v1030_rank_64_bf16.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors' --relative-path models/loras --filename 'SVI_v2_PRO_Wan2.2-I2V-A14B_HIGH_lora_rank_128_fp16.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors' --relative-path models/loras --filename 'wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors' --relative-path models/loras --filename 'lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Stable-Video-Infinity/v2.0/SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors' --relative-path models/loras --filename 'SVI_v2_PRO_Wan2.2-I2V-A14B_LOW_lora_rank_128_fp16.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' --relative-path models/text_encoders --filename 'umt5_xxl_fp8_e4m3fn_scaled.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' --relative-path models/vae --filename 'wan_2.1_vae.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' --relative-path models/vae --filename 'Wan2_1_VAE_bf16.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp8_e4m3fn.safetensors' --relative-path models/diffusion_models --filename 'Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

RUN BACKOFFS="10 20 30 60 90" && for i in 1 2 3 4 5; do comfy model download --url 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp8_e4m3fn.safetensors' --relative-path models/diffusion_models --filename 'Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors' && break; if [ $i -eq 5 ]; then echo "model-download failed after 5 attempts" >&2; exit 1; fi; SLEEP=$(echo $BACKOFFS | cut -d ' ' -f $i) && echo "model-download attempt $i failed; retrying in $SLEEP seconds" >&2; sleep $SLEEP; done

# Download input image
RUN wget --progress=dot:giga -O '/comfyui/input/Gemini_Generated_Image_jk7o1njk7o1njk7o.png' "https://cool-anteater-319.convex.cloud/api/storage/0c172877-f42a-4fa0-89ea-d40d82991fa6"
