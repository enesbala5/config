{ ... }:
let
  identities = [
    {
      alias = "github-enesbala5";
      name = "Enes Bala";
      email = "contact@enesbala.com";
      # Host github-enesbala5 IdentityFile
      signingKey = "/run/agenix/github-private-key";
    } # Not using global constants as the GitHub info will likely not change
    {
      alias = "github-f";
      name = "John Doe";
      email = "email@example.com";
      # Host github-f IdentityFile
      signingKey = "/run/agenix/github-f";
    }
  ];

  default = builtins.head identities;
in
{
  programs.git = {
    enable = true;

    # SSH commit/tag signing (same keys as origin remotes via Host aliases).
    # GitHub: add each public key with type "Signing Key" for verified commits.
    signing = {
      format = "ssh";
      signByDefault = true;
      key = default.signingKey;
    };

    includes = map (id: {
      condition = "hasconfig:remote.*.url:${id.alias}:*/**";
      contents.user = {
        inherit (id) name email signingKey;
      };
    }) identities;
  };
}
