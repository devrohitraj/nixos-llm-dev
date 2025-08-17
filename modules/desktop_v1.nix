{ config, pkgs, lib, ... }:
{
  # KWallet auto-unlock on login (optional)
  # NEW (Qt 6)
  programs.ssh.askPassword = lib.mkDefault "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # Plasma conveniences
  services.xserver.libinput.enable = lib.mkDefault true;

  # Wayland tweaks (if you need them)
  programs.xwayland.enable = lib.mkDefault true;

  # KDE settings sync/backups could be added here later.
}

