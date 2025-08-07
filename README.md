# NixOS LLM/ML Dev Environment

This is a reproducible NixOS configuration for setting up a powerful machine with:

- 🧠 Local LLM inference with **Ollama + CUDA (3090 GPU)**
- 💻 **Chrome** and **VS Code** with Python, Copilot, Jupyter
- 🧪 Dev Shell with PyTorch, Transformers, Ollama CLI
- 🧠 Optional: Cursor IDE setup script
- 🧠 Fully declarative + managed by Nix flakes

## 🧰 Getting Started

1. Clone this repo:
   ```bash
   git clone https://github.com/<your-username>/nixos-llm-dev.git
   cd nixos-llm-dev
   ```

2. Install NixOS on your machine, then run:
   ```bash
   sudo nixos-install --flake .#devbox
   ```

3. Optional: Use the dev shell for LLM development:
   ```bash
   nix develop
   ```

Enjoy reproducible AI coding!
