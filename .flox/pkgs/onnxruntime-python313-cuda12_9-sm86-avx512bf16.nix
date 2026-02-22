# ONNX Runtime 1.23.2 for NVIDIA Ampere (SM86: RTX 3090/A40) + AVX-512 BF16
# CUDA 12.9 — Requires NVIDIA driver 560+
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; cudaSupport = true; };
    overlays = [ (final: prev: { cudaPackages = final.cudaPackages_12_9; }) ];
  };
  inherit (nixpkgs_pinned) lib;

  # ── Variant-specific configuration ──────────────────────────────────
  gpuArchCMake = "86";
  cpuFlags = [ "-mavx512f" "-mavx512dq" "-mavx512vl" "-mavx512bw" "-mavx512bf16" "-mfma" ];
  variantName = "onnxruntime-python313-cuda12_9-sm86-avx512bf16";
  # ────────────────────────────────────────────────────────────────────

  customOrt = (nixpkgs_pinned.onnxruntime.override {
    cudaSupport = true;
    pythonSupport = true;
  }).overrideAttrs (oldAttrs: {
    requiredSystemFeatures = [ "big-parallel" ];
    cmakeFlags =
      let
        filtered = builtins.filter
          (f: !(lib.hasPrefix "-DCMAKE_CUDA_ARCHITECTURES" (builtins.toString f)))
          (oldAttrs.cmakeFlags or []);
      in filtered ++ [ (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" gpuArchCMake) ];
    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${lib.concatStringsSep " " cpuFlags} $CFLAGS"
    '';
  });
in
  (nixpkgs_pinned.python3Packages.onnxruntime.override {
    onnxruntime = customOrt;
  }).overrideAttrs (oldAttrs: {
    pname = variantName;
    meta = oldAttrs.meta // {
      description = "ONNX Runtime 1.23.2 for NVIDIA RTX 3090/A40 (SM86) + AVX-512 BF16 [CUDA 12.9]";
      platforms = [ "x86_64-linux" ];
    };
  })
