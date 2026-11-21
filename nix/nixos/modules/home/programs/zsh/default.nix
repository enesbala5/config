{
  pkgs,
  data,
  lib,
  ...
}:
{
  programs.zsh = {
    # Hel
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    dotDir = "${data.homeDirectory}/.config/zsh";
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''

      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source ${data.configDirectory}/tools/zsh/powerlevel10k/.p10k.zsh

      # Source Telegram credentials - Needed for `telegram-notify` script
      [ -f /run/agenix/default-telegram ] && { set -a; source /run/agenix/default-telegram; set +a; }

      PATH=~/.console-ninja/.bin:$PATH

      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

      bindkey -e

      # Ctrl-R: fzf history (after emacs keymap so ^R is not reset)
      eval "$(${pkgs.fzf}/bin/fzf --zsh)"

      # Control + backspace
      bindkey '^H' backward-kill-word

      # Control + arrows (kitty/xterm: CSI 1;5C / 1;5D)
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
      bindkey '^[[5C' forward-word
      bindkey '^[[5D' backward-word
      if [[ -n "''${terminfo[kRIT5]}" ]]; then
        bindkey "''${terminfo[kRIT5]}" forward-word
      fi
      if [[ -n "''${terminfo[kLFT5]}" ]]; then
        bindkey "''${terminfo[kLFT5]}" backward-word
      fi

      # Shift+arrows select text in the prompt; Ctrl+Shift+arrows select by word.
      # kitty sends CSI 1;2{D,C} for shift and CSI 1;6{D,C} for ctrl+shift;
      # its own ctrl+shift+arrow tab bindings are disabled in kitty.nix.
      # zsh highlights the active region via its built-in zle_highlight.
      zle-select-move() {
        (( REGION_ACTIVE )) || zle set-mark-command
        zle "$1"
      }
      zle-select-char-left()  { zle-select-move backward-char }
      zle-select-char-right() { zle-select-move forward-char }
      zle-select-word-left()  { zle-select-move backward-word }
      zle-select-word-right() { zle-select-move forward-word }
      zle -N zle-select-char-left
      zle -N zle-select-char-right
      zle -N zle-select-word-left
      zle -N zle-select-word-right

      bindkey '^[[1;2D' zle-select-char-left
      bindkey '^[[1;2C' zle-select-char-right
      bindkey '^[[1;6D' zle-select-word-left
      bindkey '^[[1;6C' zle-select-word-right

      # A plain arrow drops the selection and just moves the cursor. Bind the
      # sequences zsh uses for arrows in both normal and application cursor mode.
      # Call the current widget, not the builtin: zsh-autosuggestions wraps
      # forward-char to accept its suggestion on Right arrow.
      zle-plain-left()  { REGION_ACTIVE=0; zle backward-char }
      zle-plain-right() { REGION_ACTIVE=0; zle forward-char }
      zle -N zle-plain-left
      zle -N zle-plain-right
      bindkey '^[[D' zle-plain-left
      bindkey '^[OD' zle-plain-left
      bindkey '^[[C' zle-plain-right
      bindkey '^[OC' zle-plain-right

      # Typing over an active selection replaces it, like a normal editor.
      zle-select-self-insert() {
        if (( REGION_ACTIVE )); then
          zle kill-region
          REGION_ACTIVE=0
        fi
        zle .self-insert
      }
      zle -N self-insert zle-select-self-insert

      # OSC 52 writes to the system clipboard (kitty allows writes by default).
      zle-clipboard-set() {
        [[ -n $1 ]] || return 0
        local encoded=$(printf %s "$1" | base64 | tr -d '\n')
        printf '\e]52;c;%s\a' "$encoded"
      }

      # Selected text, independent of which end the cursor is on.
      zle-select-text() {
        if (( MARK < CURSOR )); then
          REPLY=''${BUFFER[MARK+1,CURSOR]}
        else
          REPLY=''${BUFFER[CURSOR+1,MARK]}
        fi
      }

      # Esc-w / Esc-W copy to zsh's kill ring. End the selection and leave the
      # cursor at its right edge.
      zle-select-copy() {
        local mark=$MARK cursor=$CURSOR
        zle .copy-region-as-kill
        if (( mark != cursor )); then
          (( mark > cursor )) && CURSOR=$mark
          REGION_ACTIVE=0
        fi
      }
      zle -N copy-region-as-kill zle-select-copy

      # Ctrl+Shift+C copies the prompt selection to the system clipboard.
      # kitty's ctrl+shift+c is copy_or_noop, so this runs only when kitty has
      # no mouse selection of its own. kitty may add alternate-key fields
      # (CSI key::base;mods u), so bind both encodings.
      zle-select-copy-clipboard() {
        (( REGION_ACTIVE )) || return 0
        zle-select-text
        zle-clipboard-set "$REPLY"
        zle .copy-region-as-kill
        (( MARK > CURSOR )) && CURSOR=$MARK
        REGION_ACTIVE=0
      }
      zle -N zle-select-copy-clipboard
      bindkey '^[[99;6u' zle-select-copy-clipboard
      bindkey '^[[99::57344;6u' zle-select-copy-clipboard

      # Ctrl+Shift+X cuts: clipboard + zsh kill ring, then remove the text.
      zle-select-cut() {
        (( REGION_ACTIVE )) || return 0
        zle-select-text
        zle-clipboard-set "$REPLY"
        zle .kill-region
        REGION_ACTIVE=0
      }
      zle -N zle-select-cut
      bindkey '^[[120;6u' zle-select-cut
      bindkey '^[[120::57344;6u' zle-select-cut

      setopt AUTO_CD
      ''
    ];

    shellGlobalAliases = {
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      "......" = "../../../../..";
    };

    shellAliases = {
      # General Shortcuts
      # ---------------
      ll = "ls -l";
      "s!" = "sudo !!";

      sl = "ls";
      f = "xdg-open";

      zed = "zeditor";

      keyring-import = "nix run ${data.configDirectory}/scripts/auth/keyring-import --";

      # Hyprland / DE
      # ---------------
      reload-waybar = "pkill -9 waybar && hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd(\"waybar\")'";
      toggle-special = "hyprctl --instance 0 dispatch 'hl.dsp.workspace.toggle_special(\"magic\")'";

      # DevOps / Config
      # ---------------
      manage-secret = "cd ${data.configDirectory}/nix/secrets && EDITOR='zeditor --new --wait' agenix -e";

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
      rclone-resync = "echo 'Stopping rclone service' && rclone-stop && if ! systemctl is-active --quiet rclone.service; then printf 'WARNING: This will perform a full resync. Continue? (y/N): ' && read REPLY && if [ \"$REPLY\" = \"y\" ] || [ \"$REPLY\" = \"Y\" ]; then RCLONE_CONFIG=${data.rcloneGdriveConfigPath} RCLONE_REMOTE_NAME=${data.googleDriveRemoteName} RCLONE_LOCAL_DIR=${data.googleDriveLocalDir} ${data.configDirectory}/tools/rclone/scripts/rclone-bisync.sh --resync && rclone-start; else echo 'Resync cancelled. Restarting service...' && rclone-start; fi; else echo 'Service is still running. Cannot proceed with resync.'; fi";

      # Network
      # ---------------
      flush-dns = "sudo systemctl restart nscd";

      # NixOS Shortcuts
      # ---------------
      nixos-rebuild-switch-logs = "cat ${data.configDirectory}/nix/nixos/nixos-switch.log";
      nixos-rebuild-test = "sudo nixos-rebuild test -I nixos-config=${data.configDirectory}/nix/nixos/configuration.nix";

      # Virtual Machine Shortcuts
      # ---------------
      list-vms = "ls ~/dev/misc/vms/ | grep -oP '.*?.conf' | cut -d '.' -f 1";
      start-vm = "list-vms | fzf | xargs -I {} quickemu --vm ~/dev/misc/vms/{}.conf";

      # Power Profile
      # ---------------
      power-profile-status = "systemctl status power-profile-monitor.service -f";
      power-profile-logs = "echo '=== Power Profile Handler Log ===' && tail -n 50 /tmp/power-profile-handler.log 2>/dev/null || echo 'Handler log not found'";
      power-profile-monitor-logs = "echo '=== Power Profile Monitor Log ===' && tail -n 50 /tmp/power-profile-monitor.log 2>/dev/null || echo 'Monitor log not found'";

      # Git Shortcuts
      # ---------------
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gpr = "git pull --rebase";
      # Interactive OpenCode mini on a $0 model; the prompt loads the shared
      # chunk-and-commit skill, which stops for approval before git commit.
      chunk-and-commit = "opencode mini --model opencode/hy4-flash-free --prompt '/chunk-and-commit'";
    };
  };
}
