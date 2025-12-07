{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Elixir/Erlang
            erlang
            elixir
            elixir-ls

            # Node for assets
            nodejs

            # Asset bundlers (NixOS can't run downloaded binaries)
            tailwindcss_4
            esbuild

            # File watching
            inotify-tools

            # Tools
            postgresql
          ];

          shellHook = ''
            echo "Fitness app dev shell"
            export MIX_HOME=$PWD/.mix
            export HEX_HOME=$PWD/.hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
          '';
        };
      };
    };
}
