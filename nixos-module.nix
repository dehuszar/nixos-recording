# nixos-module.nix
#
# NixOS-level prerequisites for the recording/audio stack (Bitwig, yabridge,
# Bottles/Wine).  A home-manager module cannot set these options, so they
# live here as the NixOS half of the recording flake.
{ pkgs, ... }:

{
  # Bottles/Wine uses dconf for some settings storage.
  programs.dconf.enable = true;

  # nix-ld lets dynamically linked binaries (like Wine runners from
  # Bottles) find Nix-provided shared libraries without patchelf.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    glib
    zlib
    libudev0-shim
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true; # if not already enabled
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Provide the 32-bit ELF dynamic linker for Wine's WoW64 subsystem.
  # Wine invokes /lib/ld-linux.so.2 directly to discover 32-bit Unix
  # library dependencies, even when running 64-bit Windows executables.
  system.activationScripts.ld-linux-32 = {
    deps = [ ];
    text = ''
      mkdir -p /lib
      ln -sfn ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2 /lib/ld-linux.so.2
    '';
  };
}
