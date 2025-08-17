{ config, pkgs, lib, ... }:
{
  # Time sync and journal hygiene
  services.timesyncd.enable = lib.mkDefault true;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=500M
  '';

  # Firewall skeleton (kept empty by default)
  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = lib.mkDefault [ ];
    allowedUDPPorts = lib.mkDefault [ ];
  };

  # Locale & console
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  console.keyMap     = lib.mkDefault "us";

  # Nix store GC
  nix.gc = {
    automatic = lib.mkDefault true;
    dates     = lib.mkDefault "weekly";
    options   = lib.mkDefault "--delete-older-than 14d";
  };
}
