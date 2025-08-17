{ config, pkgs, lib, ... }:
{
  # Wayland/XWayland helpers
  programs.xwayland.enable = lib.mkDefault true;
  services.xserver.libinput.enable = lib.mkDefault true;

  # Askpass for SSH (Qt 6; the old top-level alias was removed)
  programs.ssh.askPassword = lib.mkDefault "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

  # GNOME keyring was enabled system-wide in the flake; no duplication here.
  # If you ever disable it there and want it here instead, you can move:
  # services.gnome.gnome-keyring.enable = true;
  # security.pam.services.darkclown.enableGnomeKeyring = true;
}
