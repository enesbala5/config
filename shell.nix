{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    # ---
    # Nix Language
    nixd
    nixfmt-rfc-style
  ];
}
