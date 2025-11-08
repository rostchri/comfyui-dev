#!/bin/bash
source /home/comfy/startup/utils.sh

if ls /dev/nvidiactl /dev/nvidia0 >/dev/null 2>&1 || ls /dev/kfd /dev/dri/renderD* >/dev/null 2>&1; then
  if grep -lq '^0x1002$' /sys/class/drm/renderD*/device/vendor 2>/dev/null; then
    #log_message "Information about AMD-GPU via rocminfo ..."
    #rocminfo
    #log_message "Information about AMD-GPU via clinfo ..."
    #clinfo
    log_message "Starting ComfyUI development environment for AMD..."
  else
    log_message "Starting ComfyUI development environment for NVIDIA..."
  fi

  # Validate environment variables
  verify_env_vars "UV_PATH" "LOCAL_PYTHON" "LOCAL_COMFYUI" "LSYNCD_CONFIG_FILE"
  validate_commands "sleep"

  # Setup standard PATH
  setup_path

  # Install required packages - script will exit on failure
  source /home/comfy/startup/scripts/modules/packages_setup.sh

  # workspace syncing
  if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" ]; then
     # Verify lsyncd is running and restart if needed
     log_message "Verifying lsyncd service..."
     if ! is_process_running "lsyncd"; then
         log_warning "Lsyncd is not running, restarting..."
         source /home/comfy/startup/scripts/modules/sync_setup.sh
     else
         log_success "Lsyncd is running"
     fi
  fi

  # backblaze syncing
  sync_backblaze

  log_message "Running in idle mode..."
  if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" ]; then
    log_message "Will check lsyncd status every minute"
  fi

  # Start ComfyUI if requested
  if [ "${COMFY_DEV_START_COMFY:-false}" = "true" ]; then
    log_message "Starting ComfyUI..."
    source ${LOCAL_PYTHON}/.venv/bin/activate
    # Verify ComfyUI directory and navigate to it
    verify_dir "${LOCAL_COMFYUI}" "local ComfyUI directory"
    cd "${LOCAL_COMFYUI}" || {
        log_error "Failed to navigate to ComfyUI directory"
        exit 1
    }

    # Verify main.py exists
    if [ ! -f "main.py" ]; then
        log_error "main.py not found in ComfyUI directory"
        exit 1
    fi

    # Start ComfyUI with proper error handling
    # Use extra arguments from environment variable if provided
    if grep -lq '^0x1002$' /sys/class/drm/renderD*/device/vendor 2>/dev/null; then
      log_message "Starting ComfyUI for AMD..."
      # ComfyUI einmal ohne torch.compile/Inductor starten (Triton/Inductor testweise abschalten (crasht oft beim JIT-Laden))
      # global per Env (ab PyTorch 2.3 ff. gefixt)
      #export TORCH_COMPILE_DISABLE=1
      # optional: extra Logs zum Kompilierpfad
      #export TORCH_LOGS="recompiles,graph_breaks"
      #export AMD_LOG_LEVEL=4          # HIP-Runtime-Logs
      #export HSAKMT_DEBUG_LEVEL=6     # libhsakmt Logs
      #export HIP_LAUNCH_BLOCKING=1    # Synchronisiert Kernelstarts
      #python -c "import torch; torch.randn(1, device='cuda')"
      # export LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v '^/opt/rocm' | paste -sd: -)
      # bevorzugt die wheel libs aus venv
      #      export LD_LIBRARY_PATH="$(python - <<'PY'
      #import sys, pathlib
      #p = next(pathlib.Path(sys.executable).parents[1].glob('lib/python*/site-packages/torch/lib'))
      #print(str(p))
      #PY
      #):${LD_LIBRARY_PATH}"
      if [ -n "${COMFY_DEV_EXTRA_ARGS:-}" ]; then
        #HSA_OVERRIDE_GFX_VERSION=11.0.0 HCC_AMDGPU_TARGET=gfx1100 TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1 python main.py --listen "0.0.0.0" ${COMFY_DEV_EXTRA_ARGS} --use-pytorch-cross-attention --disable-smart-memory
        HCC_AMDGPU_TARGET=gfx1100 python main.py --listen "0.0.0.0" ${COMFY_DEV_EXTRA_ARGS}
      else
        #HSA_OVERRIDE_GFX_VERSION=11.0.0 HCC_AMDGPU_TARGET=gfx1100 TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1 python main.py --listen "0.0.0.0" --use-pytorch-cross-attention --disable-smart-memory
        HCC_AMDGPU_TARGET=gfx1100 python main.py --listen "0.0.0.0"
      fi
    else
      log_message "Starting ComfyUI for NVIDIA..."
      if [ -n "${COMFY_DEV_EXTRA_ARGS:-}" ]; then
        python main.py --listen "0.0.0.0" ${COMFY_DEV_EXTRA_ARGS}
      else
        python main.py --listen "0.0.0.0"
      fi
    fi

  else # no start of comfyui
    # Main monitoring loop
    while true; do
      if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" ]; then
        # Check if lsyncd is still running every minute
        if ! is_process_running "lsyncd"; then
          log_warning "Lsyncd stopped, restarting..."
          source /home/comfy/startup/scripts/modules/sync_setup.sh
        fi
      fi
      sleep 60
    done
  fi

else # no gpu found, doing nothing except waiting
  log_warning "No GPU found, only waiting ..."
  # Main monitoring loop
  while true; do
    sleep 60
  done
fi