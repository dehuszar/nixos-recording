# nixos-module.nix
#
# NixOS-level prerequisites for the recording/audio stack (Bitwig, yabridge,
# Bottles/Wine).  A home-manager module cannot set these options, so they
# live here as the NixOS half of the recording flake.
{ pkgs, lib, ... }:

let
  # Import the ntx-flash package from the local packages directory
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
  # Add ntx-flash to system packages
  environment.systemPackages = [ ntxFlash ];
  
  # Udev rules for Expert Sleepers DISTING and other USB audio devices
  # This allows non-root users to access these devices for firmware flashing
  services.udev.extraRules = ''
    # Expert Sleepers DISTING (ntx-flash compatible device)
    SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", ATTR{idProduct}=="0145", MODE="0666"
    # NXP i.MX RT devices (used by various audio interfaces)
    SUBSYSTEM=="usb", ATTR{idVendor}=="15a2", ATTR{idProduct}=="0073", MODE="0666"
  '';
  
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

  # Real-time audio limits: Bitwig and other DAWs need high memlock to run
  # real-time audio threads without page faults. rtprio gives real-time
  # scheduling priority, nice allows negative nice values for audio threads.
  security.pam.loginLimits = [
    {
      domain = "@audio";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "@audio";
      item = "rtprio";
      type = "-";
      value = "99";
    }
    {
      domain = "@audio";
      item = "nice";
      type = "-";
      value = "-19";
    }
  ];

  # Ensure your user is in the audio group so the above limits apply.
  users.groups.audio = {};

  services.pipewire = {
    enable = true; # if not already enabled
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Provide the 32-bit ELF dynamic linker for Wine's WoW64 subsystem.
  # Wine invokes /lib/ld-linux.so.2 directly to load 32-bit Unix library
  # dependencies, even when running 64-bit Windows executables.
  #
  # NixOS does not ship /lib/ld-linux.so.2 by default. Wine needs it for
  # 32-bit support (WoW64). We create it via an activation script because:
  #   - systemd-tmpfiles cannot create parent dirs for symlinks (/lib may
  #     not exist on NixOS)
  #   - the activation script runs as root during switch-to-configuration
  system.activationScripts.ld-linux-32 = {
    deps = [ ];
    text = ''
      mkdir -p /lib
      ln -sfn ${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2 /lib/ld-linux.so.2
    '';
  };
}
