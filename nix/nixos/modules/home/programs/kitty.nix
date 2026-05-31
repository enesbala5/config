{ lib, ... }:
{
  programs.kitty = {
    enable = true;
    shellIntegration = {
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

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
