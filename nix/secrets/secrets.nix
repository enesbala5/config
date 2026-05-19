let
  data = {
    username = "e";
  };

  keys = [
    # /root/.ssh/id_ed25519.pub
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDLUlxMQpQfFDEH1wc3/B4vGw+HJNyhYQI8xeIBgB86v Framework 13 - Root User"

    # /etc/ssh/ssh_host_ed25519_key.pub
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH7g+sWNdCtaVjPb7nZ8Cp2Hu6b06HgAzWi+k4N9OGrt root@nixos"

    # /home/e/.ssh/id_ed25519.pub
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGm00Erh3zQ4qlWP9kwXzXvdOovcZ8KmN8Dj/YmYDXVw E - User"
  ];

  userConfig = {
    publicKeys = keys;
    owner = data.username;
    mode = "0600";
  };

  rootConfig =  {
    publicKeys = keys;
    owner = "root";
  };
in
{
  # General
  # -------------------------------
  "default-telegram.age" = userConfig;
  "rclone-conf.age" = userConfig;

  # Coolify
  "coolify-env.age" = rootConfig;

  # Systemd Services
  # -------------------------------
  "merre-database-backup-env.age" = rootConfig;
  "coverlttr-database-backup-env.age" = rootConfig;
  "audiobookshelf-database-backup-env.age" = rootConfig;

  "restart-cloudflared-service-env.age" = rootConfig;
  "notify-server-boot-service-env.age" = rootConfig;

  # SSH
  # -------------------------------
  "ssh-config.age" = rootConfig; # Framework 13
  "home-server-ssh-config.age" = rootConfig;

  #  Keys
  "amd-server-private-key.age" = userConfig;
  "brennero-docker-private-key.age" = userConfig;
  "brennero-gitlab-private-key.age" = userConfig;
  "davide-server-private-key.age" = userConfig;
  "github-private-key.age" = userConfig;
  "gitlab-deploy-private-key.age" = userConfig;
  "home-server-private-key.age" = userConfig;
  "laconics-azure-private-key.age" = userConfig;
  "marina-casino-private-key.age" = userConfig;
}
