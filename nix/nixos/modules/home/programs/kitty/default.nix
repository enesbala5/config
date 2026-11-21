{ lib, ... }:
{
  programs.kitty = {
    enable = true;

    keybindings = {
  		# Clipboard
      "ctrl+c" = "interrupt";
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "shift+insert" = "paste_from_clipboard";

      # Scrolling
      "ctrl+up" = "scroll_line_up";
      "ctrl+down" = "scroll_line_down";

      # Window Management
      "ctrl+n" = "new_os_window_with_cwd";
      "ctrl+shift+n" = "new_os_window";

      # Encode these separately: legacy Ctrl+/ can otherwise look like Ctrl+-
      # (Pi's undo), while Ctrl+Shift+/ selects the thinking level.
      "ctrl+/" = "send_text all \\x1b[47;5u";
      "ctrl+shift+/" = "send_text all \\x1b[47;6u";

      # Physical Ctrl+Shift+P. Herdr binds ctrl+alt+p (CSI-u 112;7). Ctrl+P
      # stays a raw ^P so shells, vim, and the bar's own movement still see it.
      "ctrl+shift+p" = "send_text all \\x1b[112;7u";

      # Kitty's defaults are ctrl+tab next_tab and ctrl+shift+tab previous_tab.
      # Hand those chords to Herdr (Tab = codepoint 9; 5 = ctrl, 6 = ctrl+shift).
      "ctrl+tab" = "send_text all \\x1b[9;5u";
      "ctrl+shift+tab" = "send_text all \\x1b[9;6u";

      # This setup uses Herdr's tabs, never kitty's. Disable every kitty tab
      # shortcut so the chords pass through to the app. In particular,
      # ctrl+shift+left/right would otherwise switch kitty tabs before zsh
      # can use them for word-wise prompt selection. ctrl+tab and
      # ctrl+shift+tab above stay as Herdr forwards (they are not kitty tabs).
      "ctrl+shift+left" = "no_op"; # was previous_tab
      "ctrl+shift+right" = "no_op"; # was next_tab
      "ctrl+shift+t" = "no_op"; # was new_tab
      "ctrl+shift+q" = "no_op"; # was close_tab
      "ctrl+shift+." = "no_op"; # was move_tab_forward
      "ctrl+shift+," = "no_op"; # was move_tab_backward
    }
    // builtins.listToAttrs (map (n: {
      name = "ctrl+shift+${toString n}";
      value = "no_op"; # was goto_tab n
    }) (lib.range 1 9));

    # shellIntegration = {
    #   enableZshIntegration = true;
    #   enableBashIntegration = true;
    # };

    settings = {
      # ---
      # Fonts
      # Stylix sets font_family (monospace) and font_size; override italic/bold-italic here.
      italic_font = "Operator Mono Book Italic";
      bold_italic_font = "Operator Mono Medium Italic";
      bold_font = "Operator Mono Medium";
      font_size = "13";

      # ---
      # Cursor
      cursor_shape = "beam";
      cursor_beam_thickness = "1.5";
      cursor_trail = 0;
      cursor_trail_color = "#3b3b3b";
      cursor_blink_interval = -1;
      cursor_stop_blinking_after = "15.0";

      # ---
      # Scrollback
      scrollback_lines = 2000;

      # ---
      # Mouse
      url_style = "curly";
      focus_follows_mouse = "no";
      strip_trailing_spaces = "never";

      # ---
      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = "yes";

      # ---
      # Bell
      enable_audio_bell = "yes";
      window_alert_on_bell = "yes";
      bell_on_tab = "yes";

      # ---
      # Window
      window_padding_width = 4;
      confirm_os_window_close = 0;
      hide_window_decorations = "no";
      inactive_text_alpha = "1.0";
      background_opacity = lib.mkForce "0.9";

      # ---
      # Tab bar
      tab_bar_edge = "bottom";
      tab_bar_style = "fade";
      tab_bar_min_tabs = 2;
      tab_switch_strategy = "previous";
      tab_separator = " ┇";
      tab_title_template = "{title}";
      active_tab_font_style = "bold-italic";
      inactive_tab_font_style = "normal";

      # ---
      # Misc
      disable_ligatures = "never";
    };
  };
}
