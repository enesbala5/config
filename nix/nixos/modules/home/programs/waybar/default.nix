{
  pkgs,
  config,
  data,
  ...
}:
{
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    settings = {
      bar = {
        position = "bottom";
        height = 26;
        output = [
          "!Dell Inc. DELL U2415 7MT017CK0JAU"
          "eDP-1"
          "DP-2"
          "DP-3"
          "DP-4"
          "DP-5"
          "DP-6"
          "DP-7"
          "DP-8"
          "DP-9"
          "DP-10"
          "DP-11"
          "DP-12"
          "DP-13"
          "DP-14"
          "DP-15"
          "DP-16"
          "DP-17"
          "DP-18"
          "DP-19"
          "DP-20"
          "HDMI-A-1"
        ];
        modules-left = [
          "hyprland/workspaces"
          "custom/separator"
          "cpu"
          "custom/cpu-label"
          "custom/separator"
          "memory"
          "custom/memory-label"
          "custom/separator"
          "custom/weather"
        ];
        modules-center = [
          "clock#date"
          "custom/separator"
          "clock#time"
          # separator built in to spotify-pause;
          "custom/spotify-pause"
          "custom/spotify"
          # "image#spotify-art"
        ];
        modules-right = [
          # TODO: figure out a way to make the tray separator go away when tray is empty
          "group/tray"
          # TODO: figure out if this or some kind of manual solution involving workspaces would be better for minimizing windows,,,, i probably want to make my own cause that seems fun
          # "taskbar" "custom/separator",

          "backlight"
          "custom/separator"
          "pulseaudio"
          "custom/audio-toggle"
          "custom/separator"
          "network"
          # "custom/separator"
          # "idle_inhibitor"
          "custom/separator"
          "custom/power-consumption"
          "custom/power-profile"
          "custom/separator"
          "battery"
        ];
        "custom/separator" = {
          format = "|";
          tooltip = false;
        };
        "hyprland/workspaces" = {
          "persistent-workspaces" = {
            "*" = 5;
          };
        };
        "custom/weather" = {
          # TODO: dont give away my location lol, not that i care or its hard to find
          exec = "curl -s 'wttr.in/Tirana?format=%C,%20%f' || echo 'ERR'";
          on-click = "notify_weather.sh";
          format = "Tirana - {}";
          interval = 900;
          max-length = 40;
          tooltip = true;
        };
        "clock#date" = {
          format = "{:%A, %B %d}";
          tooltip = true;
          tooltip-format = "{:%Y-%m-%d}";
        };
        "clock#time" = {
          format = "{:%I:%M %p}";
          tooltip = true;
          tooltip-format = "{:%H:%M:%S}";
        };
        #"image#spotify-art" = {
        #	path = "/tmp/album_art.jpeg";
        #	interval = 5;
        #	size = 30;
        #};
        "custom/spotify-pause" = {
          exec = "${data.configDirectory}/scripts/music/get_paused.sh";
          on-click = "playerctl --player=spotify play-pause";
          tooltip = false;
        };
        "custom/spotify" = {
          exec = "${data.configDirectory}/scripts/music/get_playing.sh";
          on-click = "playerctl --player=spotify play-pause";
          tooltip = false;
        };
        "group/tray" = {
          orientation = "horizontal";
          modules = [
            "tray"
            "custom/separator"
          ];
        };
        tray = {
          spacing = 9;
          show-passive-icons = true;
        };
        cpu = {
          format = "{usage}%";
        };
        "custom/cpu-label" = {
          format = "CPU";
          tooltip = false;
        };
        memory = {
          format = "{percentage}%";
        };
        "custom/memory-label" = {
          format = "MEM";
          tooltip = false;
        };
        backlight = {
          format = "⛭ {}";
        };

        # wireplumber = {
        #   format = "VOL {volume}";
        #   on-click = "hyprctl dispatch exec '[float;size 90% 80%;move 5% 10%;]' kitty pulsemixer";
        # };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "{icon} {volume}% (M)";
          format-icons = {
            headphones = "☊";
            handsfree = "🕻";
            headset = "☊";
            phone = "📱";
            portable = "♫";
          };
          on-click = "${data.configDirectory}/scripts/audio/mute_toggle.sh";
          on-click-right = "hyprctl dispatch exec '[float;size 90% 80%;move 5% 10%;]' kitty pulsemixer";
          # ignored-sinks = [ "" ];
          # min-length = 8;
        };

        "custom/audio-toggle" = {
          exec = "${data.configDirectory}/scripts/audio/get_sink_toggle.sh";
          on-click = "${data.configDirectory}/scripts/audio/toggle_sink.sh";
          interval = 10;
          tooltip = "Switch Audio Output";
        };

        network = {
          format-wifi = "ᯤ {essid}";
          format-disconnected = "ᯤ Disconnected";
          max-length = 10;
          tooltip = true;
          on-click = "vicinae vicinae://launch/@dagimg-dot/vicinae-extension-wifi-commander-0/scan-wifi";
          tooltip-format = "STR {signalStrength}";
        };

        idle_inhibitor = {
          format = "IDL {icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };

        "custom/power-consumption" = {
          exec = "${data.configDirectory}/scripts/power/get_wattage.sh";
          on-click = "hyprctl dispatch exec '[float;size 90% 80%;move 5% 10%;]' kitty sudo powertop";
          format = "{}";
          interval = 10;
          tooltip = false;
        };

        "custom/power-profile" = {
          exec = "${data.configDirectory}/scripts/power/get_power_profile.sh";
          on-click = "${data.configDirectory}/scripts/power/cycle_power_profile.sh";
          format = " {}";
          interval = 10;
          # max-length = 4;
          tooltip = true;
          tooltip-format = "{}";
        };

        #  = {
        #   interval = 5;
        #   states = {
        #     warning = 30;
        #     critical = 15;
        #     dead = 5;
        #   };
        #   format = "BAT {capacity}%";
        # };
        battery = {
          interval = 60;
          states = {
            warning = 30;
            critical = 15;
            dead = 10;
          };
          format = "⚡︎ {capacity}%";
        };
      };
    };
    style = ''
                  /* required to set the bar height less than 34 */
            			* {
            					padding: 0;
            					margin: 0;
            					background-color: transparent;
            					transition-property: background-color;
            					transition-duration: .5s;
            					border-radius: 0px;
            					opacity: 1;
                      font-family: "Geist", monospace;
                      font-weight: 400;
            			}

                  /* correct text placement/baseline */
                  .modules-left, .modules-center, .modules-right { margin-bottom: -2px; }

                  /* pad modules from screen border */
                  .modules-left  { margin-left:  0px; }
                  .modules-right { margin-right: 7px; }

                  window#waybar {
            				background-color: transparent;
            				transition-property: background-color;
            				transition-duration: .5s;
            				border-radius: 5px;
                  }

                  #custom-separator {
                  	margin-bottom: 2px;
                  	padding-left: 6px;
                  	padding-right: 6px;
                    opacity: 0.5;
                  }

                  #custom-spotify-pause {
                  	margin-bottom: 2px;
                  	padding-left: 6px;
                  	padding-right: 6px;
                  }

                  #custom-power-profile, #custom-memory-label, #custom-cpu-label {
                    font-size: 9pt;
                    margin-top: 3px;
                    opacity: 0.7;
                  }

                  #custom-audio-toggle {
      							margin-left: 2px;
      							font-size: 12pt;
      	           	background-color: rgba(255, 255, 255, 0.05);
      							padding: 0px 8px 0px 8px;
                  }

                  #pulseaudio.muted {
                    opacity: 0.5;
                  }

                  tooltip {
                  	border: 1px solid #565656;
                    background-color: rgb(41, 41, 41);
                    color: #cdd6f4;
                    font-size: 12pt;
                    font-family: "Geist", monospace;
                  }

                  tooltip label {
                  	font-family: "Geist", monospace;
                  	font-size: 10pt;
                  }

                  #workspaces button {
                  	padding: 0 3px;
                    /* border-radius: 0; */
                    font-weight: 400;
                  }

                  #workspaces button.active {
                  	/* background: rgba(255, 255, 255, 0.1); */
                  }

                  #workspaces button:hover {
                  	background: rgba(255, 255, 255, 0.07);
                  }

                  #tray menu {
                  	font-family: "Geist", monospace;
                    font-weight: 400;
                  	font-size: 15pt;
                    background-color: rgb(41, 41, 41);
                  }

                  @keyframes blinking {
                  	50% {
                  		opacity: .3;
                  	}
                  }

                  #battery.dead {
                    background: red;
                    color: white;
                    border-radius: 5px;
                    padding: 0px 5px;
                  	animation: blinking .6s ease infinite;
                  }
    '';
  };
}
