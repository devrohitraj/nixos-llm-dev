{
  description = "NixOS devbox: GRUB + NVIDIA + browsers + terminal stack (HM) + devShell";

  ################################################################################
  # Inputs
  ################################################################################
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  ################################################################################
  # Outputs
  ################################################################################
  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
  let
    system = "x86_64-linux";
    lib    = nixpkgs.lib;
    pkgs   = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Safe conditional module import (no invalid `or` usage)
    maybeImport = path:
      if builtins.pathExists path
      then import path
      else ({ config, pkgs, ... }: {});

    # Home-Manager user module:
    # If ./home.nix exists we'll use it, otherwise we provide a minimal, safe default.
    hmUserModule =
      if builtins.pathExists ./home.nix then import ./home.nix else
      ({ pkgs, ... }: {
        home.username = "darkclown";
        home.homeDirectory = "/home/darkclown";
        home.stateVersion = "25.05";

        # Nice terminal/user defaults
        home.packages = with pkgs; [
          kitty
          fzf
          tmux
          nerd-fonts.fira-code
          nerd-fonts.jetbrains-mono
        ];

        programs.kitty = {
          enable = true;
          font = { name = "JetBrainsMono Nerd Font"; size = 12; };
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

        # Robust zsh (works even if bash-only files exist in reused /home)
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
            eval "$(starship init zsh)"
            alias ll="ls -lah"
          '';
        };
      });
  in
  {
    ##############################################################################
    # NixOS host(s)
    ##############################################################################
    nixosConfigurations.devbox = lib.nixosSystem {
      inherit system;

      modules = [
        # 1) Hardware + (optional) extra system config
        ./hardware-configuration.nix
        (maybeImport ./configuration.nix)

        # 2) Core system module (bootloader/NVIDIA/browsers/etc.)
        ({ config, pkgs, ... }: {
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;

          ## Bootloader: GRUB on /boot/efi
          boot.loader.systemd-boot.enable = false;
          boot.loader.efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot/efi";
          };
          boot.loader.grub = {
            enable = true;
            efiSupport = true;
            device = "nodev";
            useOSProber = true;   # show Windows
          };

          ## Desktop (KDE Plasma on SDDM). Disable if you use something else.
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.desktopManager.plasma6.enable = true;

          ## Networking
          networking.networkmanager.enable = true;

          ## NVIDIA (RTX 3090 / Ampere). 560+ requires explicit `open`.
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            open = true;
            modesetting.enable = true;
            powerManagement.enable = true;
          };

          ## Browsers + basics
          security.chromiumSuidSandbox.enable = true;  # helps Chrome launch on some setups
          environment.systemPackages = with pkgs; [
            google-chrome
            firefox
            git curl wget unzip jq
          ];

          ## Fonts (split nerd-fonts namespace)
          fonts.fontconfig.enable = true;
          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            nerd-fonts.jetbrains-mono
          ];

          ## Optional: Ollama with CUDA
          services.ollama = {
            enable = true;
            acceleration = "cuda";
          };

          ## System Zsh (HM handles user polish)
          programs.zsh.enable = true;

          ## User
          users.users.darkclown = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" ];
            shell = pkgs.zsh;
          };
        })

        # 3) Optional extra modules (loaded only if files exist)
        (maybeImport ./modules/common.nix)
        (maybeImport ./modules/desktop.nix)
        (maybeImport ./modules/terminal.nix)

        # 4) Home-Manager (as a NixOS module)
        home-manager.nixosModules.home-manager
        ({ config, pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.verbose = true;

          home-manager.users.darkclown = hmUserModule;
        })
      ];
    };

    ##############################################################################
    # Dev shells (multi-system) — Python 3.12 + uv + essentials
    ##############################################################################
    devShells = flake-utils.lib.eachDefaultSystem (sys:
      let p = import nixpkgs { system = sys; config.allowUnfree = true; };
      in {
        default = p.mkShell {
          name = "devbox-uv";
          buildInputs = with p; [
            python312
            python312Packages.pip
            python312Packages.setuptools
            uv
            git jq curl
          ];
          shellHook = ''
            printf "\n🧠 Python 3.12 + uv ready.\n"
            echo "Use: uv venv ; uv add <pkg>"
          '';
        };
      });
  };
}
