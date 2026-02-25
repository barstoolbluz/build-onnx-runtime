# ONNX Runtime 1.24.2 for NVIDIA Ampere DC (SM80: A100/A30) + AVX2
# CUDA 12.4 — Requires NVIDIA driver 550+
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; cudaSupport = true; };
    overlays = [ (final: prev: { cudaPackages = final.cudaPackages_12_4; }) ];
  };
  inherit (nixpkgs_pinned) lib fetchFromGitHub;

  # ── Variant-specific configuration ──────────────────────────────────
  gpuArchCMake = "80";
  cpuFlags = [ "-mavx2" "-mfma" ];
  variantName = "onnxruntime-python313-cuda12_4-sm80-avx2";
  # ────────────────────────────────────────────────────────────────────

  # ── ORT 1.24.2 source override ─────────────────────────────────────
  ortVersion = "1.24.2";
  ortSrc = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    tag = "v${ortVersion}";
    fetchSubmodules = true;
    hash = "sha256-eUxjijbUDoaaRDV3LASsrOK1kMCypbw3dWkoaw4ZU7Q=";
  };
  cutlass-src = fetchFromGitHub {
    name = "cutlass-src";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.2.1";
    hash = "sha256-iP560D5Vwuj6wX1otJhwbvqe/X4mYVeKTpK533Wr5gY=";
  };
  onnx-src = fetchFromGitHub {
    name = "onnx-src";
    owner = "onnx";
    repo = "onnx";
    tag = "v1.20.1";
    hash = "sha256-XZJXD6sBvVJ6cLPyDkKOW8oSkjqcw9whUqDWd7dxY3c=";
  };
  abseil-cpp-src = fetchFromGitHub {
    name = "abseil-cpp-src";
    owner = "abseil";
    repo = "abseil-cpp";
    tag = "20250814.0";
    hash = "sha256-6Ro7miql9+wcArsOKTjlyDSyD91rmmPsIfO5auk9kiI=";
  };
  # ────────────────────────────────────────────────────────────────────

  customOrt = (nixpkgs_pinned.onnxruntime.override {
    cudaSupport = true;
    pythonSupport = true;
  }).overrideAttrs (oldAttrs: {
    version = ortVersion;
    src = ortSrc;
    patches = [];
    postPatch = ''
      substituteInPlace cmake/libonnxruntime.pc.cmake.in \
        --replace-fail '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
      echo "find_package(cudnn_frontend REQUIRED)" > cmake/external/cudnn_frontend.cmake
    '';
    requiredSystemFeatures = [ "big-parallel" ];

    cmakeFlags = let
      filtered = builtins.filter (f:
        let s = builtins.toString f; in
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_CUTLASS" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_ONNX" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_ABSEIL_CPP" s) &&
        !(lib.hasPrefix "-DCMAKE_CUDA_ARCHITECTURES" s)
      ) (oldAttrs.cmakeFlags or []);
    in filtered ++ [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${cutlass-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" "${onnx-src}")
      (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" gpuArchCMake)
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ABSEIL_CPP" "${abseil-cpp-src}")
    ];

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
      description = "ONNX Runtime 1.24.2 for NVIDIA A100/A30 (SM80) + AVX2 [CUDA 12.4]";
      platforms = [ "x86_64-linux" ];
    };
  })
