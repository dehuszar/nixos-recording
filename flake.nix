{
  description = "NixOS + home-manager module for audio recording / DAW tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosModules.default = ./nixos-module.nix;
      homeManagerModules.default = ./home-module.nix;
    };
}
