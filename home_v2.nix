{ config, pkgs, lib, ... }:
{
  home.username      = "darkclown";
  home.homeDirectory = "/home/darkclown";
  home.stateVersion  = "25.05";

  # User-level packages (light set; system installs most already)
  home.packages = with pkgs; [
    kitty
    fzf
    tmux
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    settings = {
      background_opacity = "0.97";
      confirm_os_window_close = 0;
    };
  };

  programs.starship.enable = true;

  programs.tmux = {
    enable = true;
    clock24 = true;
    terminal = "screen-256color";
    extraConfig = ''
      set -g mouse on
      set -g history-limit 100000
      setw -g mode-keys vi
    '';
  };

  programs.fzf.enable = true;

  # Robust zsh init: works even if old bash-only files exist in reused /home
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # Guard against 'complete: command not found' (NVM bash_completion, etc.)
    initExtraFirst = ''
      autoload -Uz compinit bashcompinit
      compinit
      bashcompinit
    '';

    initExtra = ''
      eval "$(starship init zsh)"
      alias ll="ls -lah"
      alias gs="git status"
      alias gc="git commit"
      alias gl="git pull"
    '';
  };

  # Optional: user service to fetch Cursor AppImage into ~/Applications
  systemd.user.services.install-cursor = {
    Unit.Description = "Install Cursor IDE AppImage";
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "install-cursor" ''
        set -euo pipefail
        mkdir -p "$HOME/Applications"
        cd "$HOME/Applications"
        if [ ! -f cursor.AppImage ]; then
          ${pkgs.curl}/bin/curl -L https://cursor.sh/download -o cursor.AppImage
          chmod +x cursor.AppImage
        fi
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };

  # HM manages these dotfiles; if they already exist, flake sets:
  # home-manager.backupFileExtension = "backup";
}
