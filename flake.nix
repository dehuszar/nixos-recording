{
  description = "NixOS + home-manager module for audio recording / DAW tooling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Inline the ntx-flash package definition
      ntxFlash = let
        src = pkgs.fetchurl {
          url = "https://github.com/expertsleepersltd/ntx-flash/releases/download/v2.0.1/ntx-flash-v2.0.1-linux.tar.gz";
          sha256 = "e31f330824b0cf7ff5318a54a681f4721cd22a77ecb25f61f5258d05d6e4b07f";
        };
      in
      pkgs.stdenv.mkDerivation {
        pname = "ntx-flash";
        version = "v2.0.1";
        src = src;
        
        dontConfigure = true;
        dontBuild = true;
        
        installPhase = ''
          mkdir -p $out/bin
          cp ntx-flash $out/bin/ntx-flash
          chmod +x $out/bin/ntx-flash
        '';
      };
    in
    {
      nixosModules.default = ./nixos-module.nix;
      homeManagerModules.default = ./home-module.nix;

      # Expose the packages output so it can be composed in user configs
      packages.${system} = {
        default = ntxFlash;
        ntx-flash = ntxFlash;
      };
    };
}
