# Implementation Plan: Declarative Cursor Agent Incus Worker with Telegram Alerts

## **Objective**

Set up a declarative Incus profile and VM deployment workflow on NixOS to run Cursor Self-Hosted Agent workers in an isolated environment. The worker will consume decrypted secrets (.age) and use the host's existing notify.sh script to send Telegram updates when tasks start, succeed, or fail.

## **File Structure & Deliverables**

> 1. hosts/<hostname>/incus-vm-agentic-ai.nix: NixOS module for the Incus profile, age secret declaration, and systemd launcher.  
> 2. secrets/incus-vm-agentic-ai-secrets.age: Age-encrypted secrets file.  
> 3. secrets/secrets.nix: Agenix / Sops configuration registering the age key.  
> 4. scripts/spawn-cursor-worker.sh: Host helper script to launch an Incus VM, inject secrets, and execute the worker.

## **Step 1: Secrets Schema (secrets/incus-vm-agentic-ai-secrets.age)**

Create and encrypt your age secret with the following environment variables:  

```env
# Cursor API Auth  
CURSOR_API_KEY="cursor_xxxx..."

# Git Auth (Fine-grained PAT with repo read/write access)  
GITHUB_TOKEN="ghp_xxxx..."  
# Alternative for private SSH keys:  
# GIT_SSH_KEY="-----BEGIN OPENSSH PRIVATE KEY-----\\n..."

# Telegram Notification Credentials  
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."  
TELEGRAM_CHAT_ID="987654321"

# Environment Defaults  
WORKSPACE_DIR="/workspace"
```

> Note: User will do this manually by running `manage-secret incus-vm-agentic-ai-secrets.age` and pasting in content.

## **Step 2: NixOS Module Integration (incus-vm-agentic-ai.nix)**

Add the following NixOS configuration. It reads `${data.configDirectory}/tools/telegram/notify.sh` directly from the host filesystem into the Nix store and injects it via cloud-init into the guest VM.

```nix
{ config, pkgs, data, ... }:

let  
  # Read host telegram script directly into Nix store  
  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";  
in  
{  
  # 1\. Add declarative Cursor Worker profile to Incus preseed  
  virtualisation.incus.preseed.profiles = [  
    {  
      name = "cursor-worker";  
      config = {  
        "limits.cpu" = "4";  
        "limits.memory" = "8GiB";  
        "security.nesting" = "true"; # Required for Docker inside container/VM  
        "user.user-data" = ''  
          #cloud-config  
          package_update: true  
          packages:  
            - git  
            - curl  
            - jq  
            - build-essential  
            - docker.io  
            - ca-certificates

          write_files:  
            # Inject host notify.sh script  
            - path: /usr/local/bin/notify.sh  
              permissions: '0755'  
              owner: root:root  
              content: |  
                ${telegramScriptContent}

            # Inject task wrapper that loads env and fires Telegram events
            - path: /usr/local/bin/run-agent-task.sh  
              permissions: '0755'  
              owner: root:root  
              content: |  
                #!/usr/bin/env bash  
                set -euo pipefail

                # Load decrypted agent secrets  
                if [ -f /etc/agent-env ]; then  
                  set -o allexport  
                  source /etc/agent-env  
                  set \+o allexport  
                else  
                  echo "Error: /etc/agent-env missing" >&2  
                  exit 1  
                fi

                # Configure git auth if GITHUB_TOKEN is present  
                if [ -n "''${GITHUB_TOKEN:-}" ]; then  
                  git config --global url."https://x-access-token:''${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"  
                fi

                WORKER_NAME="$(hostname)"  
                /usr/local/bin/notify.sh -m md "🤖 \*Cursor Agent Worker Started\*\\nInstance: \\\`''${WORKER_NAME}\\\`"

                # Run worker daemon or command passed as arguments  
                if agent worker start "$@"; then  
                  /usr/local/bin/notify.sh -m md "✅ \*Cursor Agent Task Finished\*\\nInstance: \\\`''${WORKER_NAME}\\\`"  
                else  
                  EXIT_CODE=$?  
                  /usr/local/bin/notify.sh -m md "❌ \*Cursor Agent Task Failed\*\\nInstance: \\\`''${WORKER_NAME}\\\` (Exit Code: ''${EXIT_CODE})"  
                  exit ''${EXIT_CODE}  
                fi

          runcmd:  
            # Install Cursor agent CLI in VM  
            - curl https://cursor.com/install -fsS | bash  
        '';  
      };  
    }  
  ];  
}
```

## **Step 3: Worker Host Provisioning Script (spawn-cursor-worker.sh)**

Create a script on your host to orchestrate launching the VM, pushing secrets, and executing the worker process without hardcoding credentials in the VM profile.

```bash
#!/usr/bin/env bash  
set -euo pipefail

VM_NAME="${1:-cursor-worker-01}"  
SECRETS_PATH="/run/agenix/incus-vm-agentic-ai-secrets"

if [ ! -f "$SECRETS_PATH" ]; then  
  echo "Error: Secret file $SECRETS_PATH not found. Ensure agenix/sops is loaded." >&2  
  exit 1  
fi

echo "==> Launching Incus VM: $VM_NAME..."  
if ! incus info "$VM_NAME" >/dev/null 2>&1; then  
  incus launch images:ubuntu/24.04 "$VM_NAME" --profile default --profile cursor-worker --vm  
else  
  echo "VM $VM_NAME already exists, starting..."  
  incus start "$VM_NAME" || true  
fi

echo "==> Waiting for cloud-init completion..."  
incus exec "$VM_NAME" -- cloud-init status --wait

echo "==> Injecting decrypted secrets..."  
incus file push "$SECRETS_PATH" "$VM_NAME/etc/agent-env" -p 0600 --uid 0 --gid 0

echo "==> Triggering Cursor Agent worker task..."  
incus exec "$VM_NAME" -- /usr/local/bin/run-agent-task.sh
```

## **Execution Verification Checklist**

> 1. **Decrypt Check:** Run cat /run/agenix/incus-vm-agentic-ai-secrets on host to confirm sops-nix / agenix generated the file with mode 0600\.  
> 2. **Profile Check:** Run incus profile show cursor-worker to verify cloud-init user data rendered correctly without Nix syntax errors.  
> 3. **Execution Run:** Run ./spawn-cursor-worker.sh test-vm.  
> 4. **Telegram Validation:** Confirm an initial *"🤖 Cursor Agent Worker Started"* message arrives in Telegram, followed by the completion/failure notification upon task finish.
