# ~/nixos-config/nixos/flakes/opencode-ai/default.nix
{ lib, pkgs, stdenv, fetchFromGitHub, nodejs, bun, go, git, unzip, curl, coreutils }:

let
  opencodeName = "opencode-ai";
  opencodeVersion = "unstable-$(date +%Y%m%d)"; # Using unstable for latest state
in
stdenv.mkDerivation rec {
  pname = opencodeName;
  version = opencodeVersion;

  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    rev = "dev";
    # This SHA is for the *opencode source* itself.
    # You already got this one, keep it as is.
    sha256 = "sha256-vTGEdOUI2KWwQlqR6Xx28b+m75SiTJITUD5D06ooLq8=";
  };

  # =========================================================================
  # IMPORTANT: Enabling NETWORK ACCESS for the build.
  # This makes the build LESS REPRODUCIBLE. Consider this for development
  # or personal use cases where you accept this trade-off.
  # =========================================================================
  networkAccess = true; # Allow network connection during the build process

  # Allow the build to succeed even if some initial steps might "fail"
  # (e.g., if bun install returns a non-zero exit code due to a warning, but
  # still managed to put files in place). This might need to be adjusted.
  # dontBuild = true; # Can sometimes be helpful for very complex builds
  # dontConfigure = true; # Can sometimes be helpful for very complex builds
  # dontPatch = true; # Can sometimes be helpful for very complex builds
  # dontFixup = true; # Can sometimes be helpful for very complex builds

  # Build inputs are dependencies needed during the build phase (e.g., compilers, build tools)
  buildInputs = [
    nodejs # Node.js is needed for Bun, and potentially for opencode itself
    bun # Bun is used as the package manager and runtime
    go # For Go related parts of opencode-ai (if any)
    git # If the build process needs to clone submodules or other repos
    unzip # If any dependencies are downloaded as zip files
    curl # For general downloads
    coreutils # Provides common utilities like 'date' if needed, generally useful
    pkgs.gcc # C compiler
    pkgs.gnumake # Make utility
  ];

  # Propagated build inputs are dependencies that the _resulting package_ will need at runtime.
  propagatedBuildInputs = [
    nodejs
    bun
    go
  ];

  # =========================================================================
  # Simplified `installPhase`
  #
  # We are relying on `bun install` to handle fetching dependencies directly
  # over the network.
  # =========================================================================
  installPhase = ''
    echo "Running network connectivity test..."
    # Attempt to curl a well-known site
    curl -v -o /dev/null https://www.google.com || {
      echo "ERROR: Network connectivity test failed. Network access is still blocked."
      exit 1
    }
    echo "Network connectivity test successful."

    echo "Running bun install with network access..."
    export PATH="${nodejs}/bin:${bun}/bin:${go}/bin:${git}/bin:${unzip}/bin:${curl}/bin:$PATH"

    cd . # Stay in the unpacked source directory

    bun install || bun install # Allow bun to resolve and potentially re-lock

    mkdir -p $out/share/${opencodeName}
    cp -a . $out/share/${opencodeName}

    mkdir -p $out/bin
    cat <<EOF > $out/bin/${opencodeName}
    #!/bin/${pkgs.stdenv.shell}
    echo "Starting ${opencodeName}..."
    cd $out/share/${opencodeName}
    export PATH="${nodejs}/bin:${bun}/bin:${go}/bin:$PATH"
    exec bun run packages/opencode/src/index.ts "\$@"
    EOF
    chmod +x $out/bin/${opencodeName}
    echo "opencode-ai derivation installation complete."
  '';

  meta = with lib; {
    description = "A NixOS derivation for opencode-ai from its Git source (with network access enabled during build).";
    homepage = "https://github.com/sst/opencode";
    license = licenses.gpl3; # Please adjust to the actual license of opencode-ai
    platforms = platforms.linux;
  };
}
