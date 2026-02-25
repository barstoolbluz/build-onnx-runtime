# ONNX Runtime 1.20.1 for NVIDIA Hopper (SM90: H100/Grace Hopper) + ARMv9 (Graviton3+, Grace)
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
  gpuArchCMake = "90";
  cpuFlags = [ "-march=armv9-a+sve2" ];
  variantName = "onnxruntime-python313-cuda12_4-sm90-armv9";
  # ────────────────────────────────────────────────────────────────────

  # ── ORT 1.20.1 source override ─────────────────────────────────────
  ortVersion = "1.20.1";
  ortSrc = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    tag = "v${ortVersion}";
    fetchSubmodules = true;
    hash = "sha256-xIjR2HsVIqc78ojSXzoTGIxk7VndGYa8o4pVB8U8oXI=";
  };
  cutlass-src = fetchFromGitHub {
    name = "cutlass-src";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v3.5.1";
    hash = "sha256-sTGYN+bjtEqQ7Ootr/wvx3P9f8MCDSSj3qyCWjfdLEA=";
  };
  onnx-src = fetchFromGitHub {
    name = "onnx-src";
    owner = "onnx";
    repo = "onnx";
    tag = "v1.16.1";
    hash = "sha256-I1wwfn91hdH3jORIKny0Xc73qW2P04MjkVCgcaNnQUE=";
  };
  nsync-src = fetchFromGitHub {
    name = "nsync-src";
    owner = "google";
    repo = "nsync";
    tag = "1.26.0";
    hash = "sha256-pE9waDI+6LQwbyPJ4zROoF93Vt6+SETxxJ/UxeZE5WE=";
  };
  utf8_range-src = fetchFromGitHub {
    name = "utf8_range-src";
    owner = "protocolbuffers";
    repo = "utf8_range";
    rev = "72c943dea2b9240cd09efde15191e144bc7c7d38";
    hash = "sha256-rhd035bVtMYrHl6yzrchKuYPrscHC5uxivdyzDtIwo0=";
  };
  cpuinfo-src = fetchFromGitHub {
    name = "cpuinfo-src";
    owner = "pytorch";
    repo = "cpuinfo";
    rev = "ca678952a9a8eaa6de112d154e8e104b22f9ab3f";
    hash = "sha256-UKy9TIiO/UJ5w+qLRlMd085CX2qtdVH2W3rtxB5r6MY=";
  };
  pthreadpool-src = fetchFromGitHub {
    name = "pthreadpool-src";
    owner = "Maratyszcza";
    repo = "pthreadpool";
    rev = "4fe0e1e183925bf8cfa6aae24237e724a96479b8";
    hash = "sha256-R4YmNzWEELSkAws/ejmNVxqXDTJwcqjLU/o/HvgRn2E=";
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
      substituteInPlace onnxruntime/core/optimizer/transpose_optimization/optimizer_api.h \
        --replace-fail "#pragma once" "#pragma once
#include <cstdint>"
      substituteInPlace onnxruntime/core/optimizer/transpose_optimization/onnx_transpose_optimization.cc \
        --replace-fail "#include <cassert>" "#include <cassert>
#include <cstring>"
      # Backport protobuf 5.26+ compatibility from ORT 1.22.2
      sed -i '/ClearedCount/,+3d' onnxruntime/core/graph/graph.cc
      # Fix clog: system cpuinfo doesn't export separate clog target
      substituteInPlace cmake/external/onnxruntime_external_deps.cmake \
        --replace-fail "set(ONNXRUNTIME_CLOG_TARGET_NAME clog)" \
        "set(ONNXRUNTIME_CLOG_TARGET_NAME cpuinfo::cpuinfo)"
      # Disable -Werror for GCC 15 compatibility
      substituteInPlace cmake/CMakeLists.txt \
        --replace-fail "COMPILE_WARNING_AS_ERROR ON" "COMPILE_WARNING_AS_ERROR OFF"
      substituteInPlace onnxruntime/core/platform/env.h \
        --replace-fail "GetRuntimePath() const { return PathString(); }" \
        "GetRuntimePath() const { return PathString(\"$out/lib/\"); }"
    '';
    requiredSystemFeatures = [ "big-parallel" ];

    cmakeFlags = let
      filtered = builtins.filter (f:
        let s = builtins.toString f; in
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_CUTLASS" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_ONNX" s) &&
        !(lib.hasPrefix "-Donnxruntime_BUILD_UNIT_TESTS" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_UTF8_RANGE" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_PTHREADPOOL" s) &&
        !(lib.hasPrefix "-DCMAKE_CUDA_ARCHITECTURES" s)
      ) (oldAttrs.cmakeFlags or []);
    in filtered ++ [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${cutlass-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" "${onnx-src}")
      (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
      (lib.cmakeBool "onnxruntime_ENABLE_WERROR" false)
      (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" false)
      (lib.cmakeBool "onnxruntime_BUILD_UNIT_TESTS" false)
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" "${nsync-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_UTF8_RANGE" "${utf8_range-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" "${cpuinfo-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PTHREADPOOL" "${pthreadpool-src}")
      (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" gpuArchCMake)
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="-Wno-error ${lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${lib.concatStringsSep " " cpuFlags} $CFLAGS"
    '';
  });
in
  (nixpkgs_pinned.python3Packages.onnxruntime.override {
    onnxruntime = customOrt;
  }).overrideAttrs (oldAttrs: {
    pname = variantName;
    meta = oldAttrs.meta // {
      description = "ONNX Runtime 1.20.1 for NVIDIA H100/Grace Hopper (SM90) + ARMv9 (Graviton3+, Grace) [CUDA 12.4]";
      platforms = [ "aarch64-linux" ];
    };
  })
