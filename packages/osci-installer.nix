# osci-installer — the official installer app for osci-render / sosci.
#
# sosci is a paid-license product.  Its premium artifacts cannot be fetched
# reproducibly by Nix: the release CDN refuses downloads without an
# activation token issued after license-key entry (see
# https://jameshball.releaseplane.org/api/version/download-url).  The
# supported way to install sosci is therefore to run this installer once:
# it activates your license, downloads the latest sosci build (binary +
# sosci.vst3) into directories you choose, and refreshes the activation
# on later runs (which doubles as the update mechanism).
#
# The installer binary itself is a locally-purchased copy kept outside the
# store in nixos-config/sources/ (same pattern as pianoteq/vcvrack-pro),
# passed in via `src`.
#
# Runtime note: the app dlopen()s UNVERSIONED sonames
# (libwebkit2gtk-4.1.so, libgtk-3.so, libglib-2.0.so, libgio-2.0.so,
# libsoup-3.0.so, plus assorted X11 libs).  Ubuntu ships those names in
# its packages; nixpkgs only exposes the versioned .so.N — and now even
# the webkit 4.1 API itself is gone (only webkitgtk_6_0 remains), so we
# alias the probed names onto the 6.0 lib best-effort.  Without them the
# installer's legal-doc webview fails to construct and the app segfaults
# in initialise() → centreWithSize().
{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  curl,
  fontconfig,
  freetype,
  glib,
  gtk3,
  libpulseaudio,
  libsoup_3,
  stdenv,
  webkitgtk_6_0,
  libx11,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxinerama,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxcb,
  src,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "osci-installer";
  version = "1.0.2.8";

  inherit src;
  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    curl
    fontconfig
    freetype
    (lib.getLib glib)
    (lib.getLib gtk3)
    stdenv.cc.cc.lib
    libx11
    libxext
    libxrender
  ];

  # Everything the binary probes for with dlopen().
  dlisOpenPath = lib.makeLibraryPath [
    alsa-lib
    curl
    fontconfig
    freetype
    (lib.getLib glib)
    (lib.getLib gtk3)
    libpulseaudio
    libsoup_3
    stdenv.cc.cc.lib
    webkitgtk_6_0
    libx11
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxrandr
    libxrender
    libxscrnsaver
    libxcb
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share/applications
    install -m755 $src $out/bin/osci-installer

    # Synthesize the unversioned .so names the installer dlopen()s.
    #
    # Best-effort webkit shim: the app (JUCE 7) probes for
    # libwebkit2gtk-4.1/4.0.so, but current nixpkgs only ships WebKitGTK's
    # 6.0 ABI (webkitgtk_6_0; the 4.1 API was removed).  The 6.0 lib keeps
    # the vast majority of webkit_* symbols JUCE needs, so we alias the
    # probed names onto it.  If the installer's legal-docs page misbehaves,
    # this is the first suspect — everything else runs headless of webkit.
    #
    # mk <link-name> <dir> <prefix> resolves the first <prefix>.so* in the
    # dir (real file may carry a .so.0.x suffix).
    mk() {
      local target
      target=$(find "$2" -maxdepth 1 -name "$3.so*" 2>/dev/null | sort | head -1)
      if [ -n "$target" ]; then
        ln -s "$target" "$out/lib/$1"
      else
        echo "WARNING: no $3.so* in $2 — dlopen of $1 would fail" >&2
      fi
    }
    mk libwebkit2gtk-4.1.so        ${webkitgtk_6_0}/lib libwebkitgtk-6.0
    mk libwebkit2gtk-4.0.so        ${webkitgtk_6_0}/lib libwebkitgtk-6.0
    mk libjavascriptcoregtk-4.1.so ${webkitgtk_6_0}/lib libjavascriptcoregtk-6.0
    mk libjavascriptcoregtk-4.0.so ${webkitgtk_6_0}/lib libjavascriptcoregtk-6.0
    mk libsoup-3.0.so              ${libsoup_3}/lib libsoup-3.0
    mk libsoup-2.4.so              ${libsoup_3}/lib libsoup-3.0
    mk libgtk-3.so                 ${lib.getLib gtk3}/lib libgtk-3
    mk libglib-2.0.so              ${lib.getLib glib}/lib libglib-2.0
    mk libgio-2.0.so               ${lib.getLib glib}/lib libgio-2.0

    wrapProgram $out/bin/osci-installer \
      --prefix LD_LIBRARY_PATH : "$out/lib:$dlisOpenPath" \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1

    cat > $out/share/applications/osci-installer.desktop <<'EOF'
[Desktop Entry]
Name=osci-render / sosci installer
GenericName=Oscilloscope music installer
Comment=Activate your osci-render license and install/update sosci
Exec=osci-installer
Icon=application-x-executable
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Settings;
EOF

    runHook postInstall
  '';

  meta = {
    description = "Installer/updater for osci-render and sosci (paid license)";
    homepage = "https://osci-render.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "osci-installer";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
