{
  description = "NixOS setup for ML/LLM devs with 3090 GPU, Ollama, Chrome, VS Code, Cursor, and Home Manager.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
   #  home-manager = {
   #   url = "github:nix-community/home-manager/release-25.05";
   #   inputs.nixpkgs.follows = "nixpkgs";
   #  };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, ... }: {

    ############################
    #  NixOS Configuration
    ############################
    nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
         # Terminal + Fonts + Zsh system-wide
          ({ pkgs, ... }: {
            environment.systemPackages = with pkgs; [
              kitty
              tmux
              fzf
            ];

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

            fonts.packages = with pkgs; [
  nerd-fonts.fira-code
  nerd-fonts.jetbrains-mono
];

        home-manager.nixosModules.home-manager,
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # <-- add these two lines
  home-manager.backupFileExtension = "backup";
  home-manager.verbose = true;


          home-manager.users.darkclown = import ./home.nix;
        }
        ({ config, pkgs, ... }: {
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;

          # Bootloader (GRUB on EFI)
          boot.loader.systemd-boot.enable = false;
          boot.loader.efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot/efi";
          };
          boot.loader.grub = {
            enable = true;
            efiSupport = true;
            device = "nodev";
            useOSProber = true;
          };
          programs.zsh.enable = true;

          # NVIDIA GPU
          services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
  };

          # Ollama LLM runtime
          services.ollama = {
            enable = true;
            acceleration = "cuda";
          };

          # System Packages
          environment.systemPackages = with pkgs; [
            google-chrome
            vscode
            ollama
            python312
            python312Packages.pytorch
            python312Packages.transformers
            git
            wget curl unzip
            zsh
            uv
            pipx
            firefox
            # nice CLI set:
            direnv fzf zoxide eza bat ripgrep fd
          ];

            # programs.zsh.enable = true;
            programs.xwayland.enable = true;

          # Desktop & Networking
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.desktopManager.plasma6.enable = true;
          networking.networkmanager.enable = true;

          # User
          users.users.darkclown = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" ];
            shell = pkgs.zsh;
          };

          # Cursor IDE auto-install
          systemd.user.services.install-cursor = {
            description = "Install Cursor IDE AppImage";
            wantedBy = [ "default.target" ];
            script = ''
              mkdir -p /home/darkclown/Applications
              cd /home/darkclown/Applications
              if [ ! -f cursor.AppImage ]; then
                wget https://cursor.sh/download -O cursor.AppImage
                chmod +x cursor.AppImage
              fi
            '';
          };
        })

        # Home Manager
        home-manager.nixosModules.home-manager
        {
        #  home-manager.useUserPackages = true;
        #  home-manager.useGlobalPkgs = true;
          home-manager.users.darkclown = { pkgs, ... }: {
            home.stateVersion = "25.05";
            programs.home-manager.enable = true;
            home.homeDirectory = "/home/darkclown";

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

              programs.zsh = {
                enable = true;
                enableCompletion = true;
                autosuggestion.enable = true;
                syntaxHighlighting.enable = true;
                initExtraFirst = ''
                  eval "$(starship init zsh)"
                '';
              };

              programs.starship.enable = true;
              programs.tmux.enable = true;
              programs.fzf.enable = true;

             home.packages = with pkgs; [
                kitty
                fzf
                tmux
                 nerd-fonts.fira-code
  nerd-fonts.jetbrains-mono
];

            programs.vscode = {
              enable = true;
              extensions = with pkgs.vscode-extensions; [
                ms-python.python
                ms-toolsai.jupyter
                github.copilot
                github.copilot-chat
                ms-vscode.cpptools
                formulahendry.code-runner
              ];
            };
          };
        }
      ];
    };

    ############################
    #  Dev Shell
    ############################
    devShells = flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        default = pkgs.mkShell {
          name = "llm-dev-shell";
          buildInputs = with pkgs; [
            python312
            python312Packages.pip
            python312Packages.setuptools
            python312Packages.pytorch
            python312Packages.transformers
            ollama
            git
            jq
            curl
          ];
          shellHook = ''
            echo "\n🧠 Welcome to your ML/LLM dev shell (Python + Ollama ready)"
            echo "Activate your virtualenv or use 'ollama run <model>' to test"
          '';
        };
      });
  };
}
