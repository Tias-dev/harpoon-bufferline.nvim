{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {pkgs, ...}: let
        harpoon-bufferline = pkgs.vimUtils.buildVimPlugin {
          name = "harpoon-bufferline";
          src = ./.;
        };
      in {
        packages.default = harpoon-bufferline;
        packages.dev-nvim = pkgs.neovim.override {
          configure = {
            customRC = ''
              lua << EOF
                require("bufferline").setup({})
                require("harpoon").setup({})
                require("harpoon-bufferline").setup({})
              EOF
            '';
            packages.developPackages = {
              start = with pkgs.vimPlugins; [harpoon2 bufferline-nvim harpoon-bufferline];
            };
          };
        };
      };
    };
}
