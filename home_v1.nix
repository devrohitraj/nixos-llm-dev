# /etc/nixos/nixos-llm-dev/home.nix
{ config, pkgs, ... }: {
  home.username = "darkclown";
  home.homeDirectory = "/home/darkclown";
  home.stateVersion = "25.05";

  # Terminal apps (user-level too, so settings apply cleanly)
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

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # Make zsh robust if bash-only completion files exist (e.g., from old NVM)
    initExtraFirst = ''
      autoload -Uz compinit bashcompinit
      compinit
      bashcompinit
    '';

    # Nice aliases; Starship prompt
    initExtra = ''
      eval "$(starship init zsh)"
      alias ls="ls --color=auto"
      alias ll="ls -lah"
    '';
  };
}
