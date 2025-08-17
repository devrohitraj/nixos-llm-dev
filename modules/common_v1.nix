{ config, pkgs, lib, ... }:
{
  # Some sensible defaults
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  console.keyMap = lib.mkDefault "us";

  # Improve DNS reliability (edit for your network)
  services.resolved = {
    enable = lib.mkDefault true;
    dnssec = lib.mkDefault "allow-downgrade";
  };

  # Trim journal/logs & Nix store GC timers (won't delete live gens)
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 14d";
  };

  # Don’t duplicate zsh here—system zsh is enabled in flake’s inline module.
}

