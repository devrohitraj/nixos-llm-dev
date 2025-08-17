{ config, pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    eza
    bat
    ripgrep
    fd
    zoxide
  ];
}
