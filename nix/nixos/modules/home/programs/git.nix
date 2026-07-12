{ lib, ... }:
let
  identities = [
    {
      alias = "github-enesbala5";
      name = "Enes Bala";
      email = "enes@contact@enesbala.com";
    } # Not using global constants as the GitHub info will likely not change
    {
      alias = "github-flamingo-7";
      name = "Enes Bala";
      email = "enes@flamingo.com";
    }
  ];
in
{
  programs.git.includes = map (id: {
    condition = "hasconfig:remote.*.url:${id.alias}:**";
    contents.user = { inherit (id) name email; };
  }) identities;
}
