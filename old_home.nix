# home.nix
{ config, pkgs, ... }:
{ 
  home.username = "darkclown";
  home.homeDirectory = "/home/darkclown";
  
  programs.zsh.enable = true;
  home.stateVersion = "25.05"; # match your NixOS release
}
