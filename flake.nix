{
  description = "NixOS devbox: GRUB + NVIDIA + KDE + Browsers + Terminal + HM + DevShell + Cursor";

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

    # NEW: only for code-cursor (and any other “unstable-only” pkgs you need)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  ##############################################################################
  # Outputs
  ##############################################################################
  outputs = { self, nixpkgs, home-manager, flake-utils, nixpkgs-unstable, ... }:
  let
    system = "x86_64-linux";
    lib    = nixpkgs.lib;
    pkgs   = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Unstable set (for Cursor)
    pkgsUnstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

    # Safe conditional imports
    maybeImport = path:
      if builtins.pathExists path
      then import path
      else ({ config, pkgs, ... }: {});

    # HM user module (uses ./home.nix if present; otherwise minimal defaults)
    hmUserModule =
      if builtins.pathExists ./home.nix then import ./home.nix else
      ({ pkgs, ... }: {
        home.username      = "darkclown";
        home.homeDirectory = "/home/darkclown";
        home.stateVersion  = "25.05";

        home.packages = with pkgs; [
          kitty fzf tmux
	  nerd-fonts.fira-code
          nerd-fonts.jetbrains-mono
          # If you prefer Cursor per-user instead of system-wide, you may add:
          # (pkgsUnstable.code-cursor)
        ];

        programs.kitty = {
          enable = true;
          font = { name = "JetBrainsMono Nerd Font"; size = 12; };
          settings = { background_opacity = "0.97"; confirm_os_window_close = 0; };
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
          # robust if old bash-only files exist in reused /home
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
    # NixOS host
    ##############################################################################
    nixosConfigurations.devbox = lib.nixosSystem {
      inherit system;

      modules = [
        ./hardware-configuration.nix
        (maybeImport ./configuration.nix)

        {
  # Let nixpkgs install unfree apps like slack/zoom/spotify/obsidian
  nixpkgs.config.allowUnfree = true;

  # Shells & core dev
  programs.zsh.enable = true;
  environment.systemPackages = with pkgs; [
    # Shells
    zsh
    fish

    # Node & Rust
    nodejs_20
    rustup
    cargo
    rust-analyzer

    # Containers
    docker-compose
    podman
    podman-compose

    # Python + ML/AI
    python312
    uv
    pipx
    (python312.withPackages (ps: with ps; [
      numpy pandas matplotlib
      jupyter ipykernel
      scikit-learn
      transformers accelerate
      # Torch: CPU build (works anywhere). If you use CUDA, see note below.
      pytorch
    ]))
    # If you want CUDA for torch, prefer this instead of the CPU pytorch above:
    # python312Packages.torchWithCuda

    # Local LLM
    ollama

    # Productivity
    libreoffice
    obsidian
    slack
    discord
    zoom-us
    spotify

    # Security / SSH client
    openssh
  ];

  # Optional: enable SSH server
  services.openssh.enable = true;

  # Docker & Podman
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;
  # (Optional) if you prefer Docker to manage the default cgroup driver
  # virtualisation.docker.daemon.settings = { "exec-opts" = [ "native.cgroupdriver=systemd" ]; };

  # User to docker group (replace if your user is different)
  users.users.darkclown.extraGroups = [
    "wheel" "networkmanager" "video" "docker"
  ];

  # Ollama GPU acceleration (set to "cuda" for NVIDIA; "rocm" for AMD)
  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  # For Chromium-based browsers’ sandbox (helps with Chrome/Brave/Edge)
  security.chromiumSuidSandbox.enable = true;
}


        # Core system config
        ({ config, pkgs, ... }: {
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          nixpkgs.config.allowUnfree = true;

          ## GRUB on /boot/efi
          boot.loader.systemd-boot.enable = false;
          boot.loader.efi = { canTouchEfiVariables = true; efiSysMountPoint = "/boot/efi"; };
          boot.loader.grub = { enable = true; efiSupport = true; device = "nodev"; useOSProber = true; };

          ## KDE Plasma on SDDM
          services.xserver.enable = true;
          services.displayManager.sddm.enable = true;
          services.desktopManager.plasma6.enable = true;

          ## Network
          networking.networkmanager.enable = true;

          ## NVIDIA (RTX 3090 / Ampere) — open module as required on 560+
          services.xserver.videoDrivers = [ "nvidia" ];
          hardware.nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            open = true;
            modesetting.enable = true;
            powerManagement.enable = true;
          };

          ## Browsers + tools + Cursor
          security.chromiumSuidSandbox.enable = true;
          environment.systemPackages = with pkgs; [
            google-chrome
            firefox
            vscode-with-extensions
            python312 uv pipx
            python312Packages.pytorch
            python312Packages.transformers
            git curl wget unzip jq
            kitty fzf tmux

            # NEW: code-cursor from unstable
            (pkgsUnstable.code-cursor)
          ];

          ## Fonts
          fonts.fontconfig.enable = true;
          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            nerd-fonts.jetbrains-mono
          ];

          ## Enable keyring so Cursor/VSCode auth works smoothly
          services.gnome.gnome-keyring.enable = true;
          security.pam.services.darkclown.enableGnomeKeyring = true;

          ## Ollama (CUDA)
          services.ollama = { enable = true; acceleration = "cuda"; };

          ## Shell + user
          programs.zsh.enable = true;
          users.users.darkclown = {
            isNormalUser = true;
            extraGroups  = [ "wheel" "networkmanager" "video" ];
            shell        = pkgs.zsh;
          };
        })

        (maybeImport ./modules/common.nix)
        (maybeImport ./modules/desktop.nix)
        (maybeImport ./modules/terminal.nix)

        # Home-Manager (as a NixOS module)
        home-manager.nixosModules.home-manager
        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs       = true;
          home-manager.useUserPackages     = true;
          home-manager.backupFileExtension = "backup";
          home-manager.verbose             = true;
          home-manager.users.darkclown     = hmUserModule;
        })
      ];
    };

    ##############################################################################
    # Dev shell(s): add Cursor + Rust/ALSA like in the example
    ##############################################################################
    devShells = flake-utils.lib.eachDefaultSystem (sys:
      let
        p = import nixpkgs          { system = sys; config.allowUnfree = true; };
        u = import nixpkgs-unstable { system = sys; config.allowUnfree = true; };
      in {
        default = p.mkShell {
          name = "llm-dev-shell";
          buildInputs = with p; [
            python312 python312Packages.pip python312Packages.setuptools
            uv pipx git jq curl
            cargo rustc SDL2 alsa-lib.dev pkg-config
            # Cursor from unstable in the shell:
            u.code-cursor
          ];
          shellHook = ''
            export PKG_CONFIG_PATH=${p.alsa-lib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH
            printf "\n🧠 Python 3.12 + uv + Cursor + Rust ready.\n"
          '';
        };
      });
  };
}
