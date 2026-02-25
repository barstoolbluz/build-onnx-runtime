# ONNX Runtime 1.23.2 for NVIDIA Turing (SM75: T4/RTX 2080 Ti) + AVX-512
# CUDA 12.4 — Requires NVIDIA driver 550+
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; cudaSupport = true; };
    overlays = [ (final: prev: { cudaPackages = final.cudaPackages_12_4; }) ];
  };
  inherit (nixpkgs_pinned) lib;

  # ── Variant-specific configuration ──────────────────────────────────
  gpuArchCMake = "75";
  cpuFlags = [ "-mavx512f" "-mavx512dq" "-mavx512vl" "-mavx512bw" "-mfma" ];
  variantName = "onnxruntime-python312-cuda12_4-sm75-avx512";
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
  (nixpkgs_pinned.python312Packages.onnxruntime.override {
    onnxruntime = customOrt;
  }).overrideAttrs (oldAttrs: {
    pname = variantName;
    meta = oldAttrs.meta // {
      description = "ONNX Runtime 1.23.2 for NVIDIA T4/RTX 2080 Ti (SM75) + AVX-512 [CUDA 12.4]";
      platforms = [ "x86_64-linux" ];
    };
  })
