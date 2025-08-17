{
  description = "NixOS devbox: GRUB + NVIDIA + KDE + Browsers + Terminal + HM + DevShell";

  ##############################################################################
  # Inputs
  ##############################################################################
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  ##############################################################################
  # Outputs
  ##############################################################################
  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
  let
    system = "x86_64-linux";
    lib    = nixpkgs.lib;
    pkgs   = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Safe conditional imports for optional modules/files
    maybeImport = path:
      if builtins.pathExists path
      then import path
      else ({ config, pkgs, ... }: {});

    # Minimal HM user module if ./home.nix is missing
    hmUserModule =
      if builtins.pathExists ./home.nix then import ./home.nix else
      ({ pkgs, ... }: {
        home.username      = "darkclown";
        home.homeDirectory = "/home/darkclown";
        home.stateVersion  = "25.05";

        # Terminal stack & fonts
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

        # Optional: user service to install Cursor AppImage in ~/Applications
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
      });
  in
  {
    ##############################################################################
    # NixOS host(s)
    ##############################################################################
    nixosConfigurations.devbox = lib.nixosSystem {
      inherit system;

      modules = [
        # 1) Hardware config + optional base config file
        ./hardware-configuration.nix
        (maybeImport ./configuration.nix)

        # 2) Core system config: boot, desktop, drivers, packages
        ({ config, pkgs, ... }: {
          # Flakes & modern CLI
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;

          ######## Bootloader: GRUB on /boot/efi
          boot.loader.systemd-boot.enable = false;
          boot.loader.efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint     = "/boot/efi";
          };
          boot.loader.grub = {
            enable       = true;
            efiSupport   = true;
            device       = "nodev";
            useOSProber  = true;   # show Windows in menu
          };

          ######## Desktop: KDE Plasma 6 on SDDM
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.desktopManager.plasma6.enable = true;

          ######## Networking
          networking.networkmanager.enable = true;

          ######## NVIDIA (RTX 3090 / Ampere)
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            open = true;                 # newer 560+ needs this; good for RTX series
            modesetting.enable = true;
            powerManagement.enable = true;
          };

          ######## Browsers & tools
          security.chromiumSuidSandbox.enable = true;  # helps Chrome on some systems
          environment.systemPackages = with pkgs; [
            google-chrome
            firefox
            vscode                          # VS Code (vscode)
            # Python + managers
            python312
            uv
            pipx
            # (optional ML libs; comment out if you prefer poetry/uv to install in venv)
            python312Packages.pytorch
            python312Packages.transformers
            # CLIs
            git curl wget unzip jq
            # Terminal tools (system-wide too)
            kitty fzf tmux
          ];

          ######## Fonts (split nerd-fonts namespace)
          fonts.fontconfig.enable = true;
          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            nerd-fonts.jetbrains-mono
          ];

          ######## Ollama (CUDA)
          services.ollama = {
            enable = true;
            acceleration = "cuda";
          };

          ######## Shell
          programs.zsh.enable = true;

          ######## User
          users.users.darkclown = {
            isNormalUser = true;
            extraGroups  = [ "wheel" "networkmanager" "video" ];
            shell        = pkgs.zsh;
          };
        })

        # 3) Optional extra modules (loaded only if the files exist)
        (maybeImport ./modules/common.nix)
        (maybeImport ./modules/desktop.nix)
        (maybeImport ./modules/terminal.nix)

        # 4) Home-Manager (as a NixOS module)
        home-manager.nixosModules.home-manager
        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs     = true;
          home-manager.useUserPackages   = true;
          home-manager.backupFileExtension = "backup";
          home-manager.verbose           = true;

          home-manager.users.darkclown = hmUserModule;
        })
      ];
    };

    ##############################################################################
    # Dev shell(s): Python 3.12 + uv + pipx + basics
    ##############################################################################
    devShells = flake-utils.lib.eachDefaultSystem (sys:
      let p = import nixpkgs { system = sys; config.allowUnfree = true; };
      in {
        default = p.mkShell {
          name = "llm-dev-shell";
          buildInputs = with p; [
            python312
            python312Packages.pip
            python312Packages.setuptools
            uv pipx
            git jq curl
          ];
          shellHook = ''
            printf "\n🧠 Python 3.12 + uv ready.\n"
            echo "Tip: uv venv; uv add transformers torch"
          '';
        };
      });
  };
}
