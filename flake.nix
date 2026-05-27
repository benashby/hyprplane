{
  description = "hyprplane — plane-level workspace grouping for Hyprland";

  inputs = {
    nixpkgs.url    = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];

    perSystem = { pkgs, self', ... }: {
      formatter = pkgs.nixfmt-rfc-style;

      packages = rec {
        hyprplane = pkgs.callPackage ./nix/package.nix {};
        default   = hyprplane;
      };
    };

    flake = {
      overlays.default = _: prev: {
        hyprplane = prev.callPackage ./nix/package.nix {};
      };

      homeModules = rec {
        hyprplane = import ./nix/module.nix inputs.self;
        default   = hyprplane;
      };
    };
  };
}
