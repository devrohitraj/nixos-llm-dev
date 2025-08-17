{ config, pkgs, lib, ... }:
{
  # Extra CLI tools (system-level); most basics already come from flake’s inline module
  environment.systemPackages = with pkgs; [
    eza
    bat
    ripgrep
    fd
    zoxide
  ];

  # If you’d rather wire these into zsh aliases via HM, keep this empty and put aliases in home.nix.
}

