{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    { flake-parts, ... }@inputs:
    {
      lib = {
        mkPack =
          { name }@pack_config:
          pack_data:
          flake-parts.lib.mkFlake { inherit inputs; } {
            systems = [
              "x86_64-linux"
              "aarch64-linux"
              "x86_64-darwin"
              "aarch64-darwin"
            ];
            perSystem =
              { self', pkgs, ... }:
              {
                packages.default = pkgs.stdenv.mkDerivation {
                  name = "Pack";

                  # we don't *really* need this I think?
                  src = ./.;

                  buildPhase = (import ./modules/secret_lib.nix pkgs).makePack pack_config pack_data;
                };
              };
          };

        df = {
          unchecked = nix: {
            _df_type = "unchecked";
            _nix = nix;
          };
          checked = nix: {
            _df_type = "checked";
            _nix = nix;
          };
        };
      };
    };
}
