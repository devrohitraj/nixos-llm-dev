{ config, pkgs, lib, ... }:

{
  home.username      = "darkclown";
  home.homeDirectory = "/home/darkclown";
  home.stateVersion  = "25.05";

  # User packages (keep light; system already installs many)
  home.packages = with pkgs; [
    kitty
    fzf
    tmux
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    # If you prefer per-user Cursor instead of system-wide, uncomment:
    # (import <nixpkgs> {}).pkgsUnstable.code-cursor
    # (or better: pull pkgsUnstable via the flake; see note below)
  ];

  # Kitty
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

  # Prompt
  programs.starship.enable = true;

  # tmux
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

 # NPM global prefix & PATH (Nix-safe)
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "/home/darkclown/.npm-global";
    # ANTHROPIC_API_KEY = "sk-ant-...";  # optional
  };
  home.sessionPath = [
    "/home/darkclown/.npm-global/bin"
  ];


  # fzf
  programs.fzf.enable = true;

  # zsh (robust even if legacy bash-only files exist)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    initExtraFirst = ''
      autoload -Uz compinit bashcompinit
      compinit
      bashcompinit
    '';

    initExtra = ''
      export PATH="$HOME/.npm-global/bin:$PATH"
      eval "$(starship init zsh)"
      alias ll="ls -lah"
      alias gs="git status"
    '';
  };

  # Example: put user-level config files under XDG config
  xdg.enable = true;
}
