#!/bin/bash
# ComfyUI repository setup module
source /home/comfy/startup/utils.sh

log_message "Setting up ComfyUI repository..."

# Validate environment variables and commands
verify_env_vars "WORKSPACE_DIR" "WORKSPACE_COMFYUI" "LOCAL_COMFYUI" "COMFY_REPO"
validate_commands "git" "grep" "sed"


# Function to execute extension callback if defined
execute_extension_callback() {
    log_message "======================= EXTENSION SETUP ====================="
    if [ -n "${COMFY_DEV_ON_SETUP_COMFYUI_CALLBACK:-}" ]; then
        log_message "Extension callback is set to: ${COMFY_DEV_ON_SETUP_COMFYUI_CALLBACK}"
        if [ -f "${COMFY_DEV_ON_SETUP_COMFYUI_CALLBACK}" ]; then
            log_message "Running extension: ${COMFY_DEV_ON_SETUP_COMFYUI_CALLBACK}"
            source "${COMFY_DEV_ON_SETUP_COMFYUI_CALLBACK}" || {
                log_error "Extension setup failed"
                exit 1
            }
        fi
    else
        log_message "No extension callback is set"
    fi
}

# Different behaviors based on role
if [[ "${COMFY_DEV_ROLE}" == "LEADER" ]]; then
    # LEADER BEHAVIOR
    log_message "Setting up ComfyUI as LEADER..."
    
    # Navigate to workspace - exit if workspace directory doesn't exist
    verify_dir "${WORKSPACE_DIR}" "workspace directory"
    cd "${WORKSPACE_DIR}"

    # Check whether the WORKSPACE_COMFYUI directory exists or empty, if it does, then sync_dirs from WORKSPACE_COMFYUI to LOCAL_COMFYUI, otherwise clone the repository
    if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" -a -d "${WORKSPACE_COMFYUI}" ] && ! is_dir_empty "${WORKSPACE_COMFYUI}"; then
        log_message "Syncing ComfyUI repository from workspace (${WORKSPACE_COMFYUI}) to local (${LOCAL_COMFYUI}) ..."
        sync_dirs "${WORKSPACE_COMFYUI}" "${LOCAL_COMFYUI}" "ComfyUI repository"
    elif [ ! -d "${LOCAL_COMFYUI}" ]; then # Clone ComfyUI repository if it doesn't exist
        log_message "Cloning ComfyUI repository from repository ${COMFY_REPO} to home ${LOCAL_COMFYUI} ..."
        git clone "${COMFY_REPO}" "${LOCAL_COMFYUI}"
        log_success "ComfyUI repository cloned successfully."

        log_message "Copying extra_model_paths.yaml to home ComfyUI directory..."
        cp -vf ~/startup/config/comfy/extra_model_paths.yaml "${LOCAL_COMFYUI}/"

        # Print the local ComfyUI directory
        ls -la "${LOCAL_COMFYUI}"
    fi

    # Verify the local ComfyUI directory is valid
    verify_dir "${LOCAL_COMFYUI}" "home ComfyUI repository"

if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" ]; then
    # Set up workspace ComfyUI directory
    log_message "Setting up workspace ComfyUI directory..."
    ensure_dir "${WORKSPACE_COMFYUI}" "comfy"
fi

    # Execute the extension callback
    execute_extension_callback

if [ "$COMFY_DEV_WORSPACE_SYNC" = "true" ]; then
    # Sync from local to workspace to ensure the latest content
    log_message "Syncing ComfyUI repository from local to workspace directory..."
    sync_dirs "${LOCAL_COMFYUI}" "${WORKSPACE_COMFYUI}" "ComfyUI repository"
fi

    # Signal ComfyUI setup completion
    touch /workspace/.setup/comfyui_ready

else
    # FOLLOWER BEHAVIOR
    log_message "Setting up ComfyUI as FOLLOWER..."

    # Wait for leader to complete ComfyUI setup
    wait_for_leader_completion "comfyui_ready"

    # Verify the workspace ComfyUI directory is valid
    verify_dir "${WORKSPACE_COMFYUI}" "ComfyUI repository (from leader)"

    # Set up local ComfyUI directory
    log_message "Setting up local ComfyUI directory..."
    ensure_dir "${LOCAL_COMFYUI}" "comfy"

    # Sync from workspace to local
    log_message "Syncing ComfyUI repository from workspace to local..."
    sync_dirs "${WORKSPACE_COMFYUI}" "${LOCAL_COMFYUI}" "ComfyUI repository"
fi

log_success "ComfyUI repository setup complete."