# Fix: Avoid building `rusty-v8` from source

## Problem

NixOS builds take very long because `rusty-v8-147.2.1` compiles from source (~30+ minutes, very resource-hungry). This is the Rust binding layer for Google's V8 JavaScript engine (~600k lines of C++). It's not something we explicitly installed — it's a deep transitive dependency.

### Dependency chain

```
mpv (with yt-dlp propagated)
  └── yt-dlp 2026.03.17
        └── deno 2.7.9          (hardcoded at build time via substituteInPlace)
              └── rusty-v8 147.2.1   (Rust bindings to V8)
                    └── V8 engine    (~600k lines of C++, built from source)
```

### Root cause

Since yt-dlp version `2025.11.12`, YouTube requires executing JavaScript to decipher video URLs. nixpkgs chose **deno** as the JS runtime for this. On `nixos-unstable`, a [recent change](https://github.com/NixOS/nixpkgs/pull/489526) switched `rusty-v8` from downloading a pre-built binary to **building V8 from source** — for reproducibility. This is what causes the massive build time.

yt-dlp wires in deno via a `substituteInPlace` that hardcodes the nix store path to the deno binary at build time, so simply "having deno installed separately" doesn't work — it must be the same `deno` parameter passed to yt-dlp's derivation.

### Why not just disable JS support?

yt-dlp has a `javascriptSupport` flag, but disabling it means **some YouTube videos will fail** to download (can't decipher URLs). Not an option.

---

## Solution

Override yt-dlp to use **stable nixpkgs' deno** (which downloads a pre-built rusty-v8 binary) instead of unstable's (which builds from source). This requires a second nixpkgs input pinned to stable.

### 1. Add stable nixpkgs input in `flake.nix`

```nix
inputs = {
  nixpkgs.url = "nixpkgs/nixos-unstable";
  nixpkgs-stable.url = "nixpkgs/nixos-25.05";   # <-- add
};
```

### 2. Pass stable pkgs to configuration.nix

```nix
outputs = inputs@{ self, nixpkgs, nixpkgs-stable, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    stable-pkgs = nixpkgs-stable.legacyPackages.${system};  # <-- add
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; stable-pkgs = stable-pkgs; };  # <-- pass it
      modules = [ ./configuration.nix ];
    };
  };
```

### 3. Override yt-dlp in `configuration.nix`

Update the function signature to accept `stable-pkgs`:

```nix
{ config, pkgs, inputs, stable-pkgs, ... }:
```

Then override yt-dlp wherever it's used. In the mpv block:

```nix
(mpv.overrideAttrs (oldAttrs: {
  propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ (yt-dlp.override { deno = stable-pkgs.deno; }) ];
}))
```

And if yt-dlp is also in `environment.systemPackages` directly, override it there too:

```nix
(yt-dlp.override { deno = stable-pkgs.deno; })
```

---

## Result

```
yt-dlp (unstable — latest version, full YouTube support)
  └── deno (from stable 25.05)
        └── rusty-v8 (pre-built binary — seconds, not 30+ minutes)
```

- yt-dlp stays on the latest unstable version (important — YouTube breaks constantly)
- JavaScript support stays enabled (full YouTube compatibility)
- No more compiling V8 from source
- Trade-off: slightly larger closure (stable deno is a different version than unstable's, so both copies exist in the store — but since nothing else in the config depends on deno, unstable's copy simply won't be built)

## Files to change

1. `/home/kajdo/etc/nixos/flake.nix` — add `nixpkgs-stable` input, pass `stable-pkgs`
2. `/home/kajdo/etc/nixos/configuration.nix` — accept `stable-pkgs`, override yt-dlp
