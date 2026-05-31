{ pkgs, data, ... }:
{
  programs.zsh = {
	  # Hel
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    dotDir = "${data.homeDirectory}/.config/zsh";

    initContent = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source ${data.configDirectory}/tools/zsh/powerlevel10k/.p10k.zsh

      # Source Telegram credentials - Needed for `telegram-notify` script
	    [ -f /run/agenix/default-telegram ] && set -a && source /run/agenix/default-telegram

      PATH=~/.console-ninja/.bin:$PATH

      bindkey -e

      # Control + backspace
      bindkey '^H' backward-kill-word

      # Control + arrows
      bindkey ";5C" forward-word
      bindkey ";5D" backward-word
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "fzf"
        "z"
      ];
    };

    shellAliases = {
      # General Shortcuts
      # ---------------
      ll = "ls -l";
      "s!" = "sudo !!";

      sl = "ls";
      f = "xdg-open";

      reload-hyprlock = "${data.configDirectory}/scripts/utilities/reload-hyprlock.sh";
      clear-monitor-config = "sh -c '> ~/.config/hypr/monitors.conf' && pkill -9 -f hyprdynamicmonitors";
      toggle-polarity = "${data.configDirectory}/scripts/utilities/toggle-polarity.sh";
      fix-history = "${data.configDirectory}/tools/zsh/scripts/fix-history.sh";

      # Development Shortcuts
      # ---------------
      ssh = "kitten ssh";
      sail = "./vendor/bin/sail";
      search = "nix search nixpkgs";

      # RClone
      # ---------------
      rclone-status = "systemctl status rclone.service -f";
      rclone-logs = "journalctl -u rclone.service -f";
      rclone-start = "echo 'Starting rclone service' && sudo systemctl start rclone.timer rclone.path rclone.service && (systemctl is-active --quiet rclone.service && echo 'Service started.' || echo 'Service did not start.') && echo 'Run rclone-logs or rclone-status for more information.'";
      rclone-stop = "sudo systemctl stop rclone.timer rclone.path rclone.service && sleep 1 && (! systemctl is-active --quiet rclone.service && echo 'Service stopped.' || echo 'Service did not stop.') && echo 'Run rclone-logs or rclone-status for more information.'";
      rclone-resync = "echo 'Stopping rclone service' && rclone-stop && if ! systemctl is-active --quiet rclone.service; then printf 'WARNING: This will perform a full resync. Continue? (y/N): ' && read REPLY && if [ \"$REPLY\" = \"y\" ] || [ \"$REPLY\" = \"Y\" ]; then RCLONE_CONFIG=${data.configDirectory}/tools/rclone/rclone.conf RCLONE_REMOTE_NAME=${data.googleDriveRemoteName} RCLONE_LOCAL_DIR=${data.googleDriveLocalDir} ${data.configDirectory}/tools/rclone/scripts/rclone-bisync.sh --resync && rclone-start; else echo 'Resync cancelled. Restarting service...' && rclone-start; fi; else echo 'Service is still running. Cannot proceed with resync.'; fi";

      # NixOS Shortcuts
      # ---------------
      nixos-rebuild-switch = "${data.configDirectory}/scripts/rebuild-switch.sh";
      nixos-rebuild-switch-logs = "cat ${data.configDirectory}/nix/nixos/nixos-switch.log";
      nixos-rebuild-test = "sudo nixos-rebuild test -I nixos-config=${data.configDirectory}/nix/nixos/configuration.nix";

      # Virtual Machine Shortcuts
      # ---------------
      list-vms = "ls ~/dev/misc/vms/ | grep -oP '.*?.conf' | cut -d '.' -f 1";
      start-vm = "list-vms | fzf | xargs -I {} quickemu --vm ~/dev/misc/vms/{}.conf";

      # Power
      # ---------------
      soft-shutdown = "${data.configDirectory}/scripts/power/shutdown.sh";
      soft-reboot = "${data.configDirectory}/scripts/power/reboot.sh";

      # Power Profile
      # ---------------
      power-profile-status = "systemctl status power-profile-monitor.service -f";
      power-profile-logs = "echo '=== Power Profile Handler Log ===' && tail -n 50 /tmp/power-profile-handler.log 2>/dev/null || echo 'Handler log not found'";
      power-profile-monitor-logs = "echo '=== Power Profile Monitor Log ===' && tail -n 50 /tmp/power-profile-monitor.log 2>/dev/null || echo 'Monitor log not found'";

      # Git Shortcuts
      # ---------------
      gs = "git status";
      gpr = "git pull --rebase";

      telegram-notify = "${data.configDirectory}/tools/telegram/notify.sh";

      flush-dns = "sudo systemctl restart nscd";

      zed = "zeditor";
      cursor = "appimage-run ${data.homeDirectory}/programs/cursor/cursor.AppImage";

      manage-secret = "cd ${data.configDirectory}/nix/secrets && EDITOR='zeditor --wait' agenix -e";

      decrypt-rclone-conf = "cd ${data.configDirectory}/nix/secrets && agenix --decrypt rclone-conf.age > ${data.configDirectory}/tools/rclone/rclone.conf";
    };
  };
}
