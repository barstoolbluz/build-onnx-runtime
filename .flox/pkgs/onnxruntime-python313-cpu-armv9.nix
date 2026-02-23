# ONNX Runtime 1.18.1 CPU-only + ARMv9 (Graviton3+, Grace)
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; };
  };
  inherit (nixpkgs_pinned) lib fetchFromGitHub;

  # ── Variant-specific configuration ──────────────────────────────────
  cpuFlags = [ "-march=armv9-a+sve2" ];
  variantName = "onnxruntime-python313-cpu-armv9";
  # ────────────────────────────────────────────────────────────────────

  # ── ORT 1.18.1 source override ─────────────────────────────────────
  ortVersion = "1.18.1";
  ortSrc = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    tag = "v${ortVersion}";
    fetchSubmodules = true;
    hash = "sha256-+zWtbLKekGhwdBU3bm1u2F7rYejQ62epE+HcHj05/8A=";
  };
  onnx-src = fetchFromGitHub {
    name = "onnx-src";
    owner = "onnx";
    repo = "onnx";
    tag = "v1.16.0";
    hash = "sha256-mgYrY3IXUMgG/2/SjwMWAX0FneY+E8SpLDMnB9EUbF4=";
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
    rev = "959002f82d7962a473d8bf301845f2af720e0aa4";
    hash = "sha256-nOSaLZGqmt+8W5Ut9QHDKznh1cekl1jL2ghCM4mgbgc=";
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
    cudaSupport = false;
    pythonSupport = true;
  }).overrideAttrs (oldAttrs: {
    version = ortVersion;
    src = ortSrc;
    patches = [];
    postPatch = ''
      substituteInPlace cmake/libonnxruntime.pc.cmake.in \
        --replace-fail '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
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
      # Fix protobuf discovery: remove version constraint, add lowercase name (backport from ORT 1.20.1)
      substituteInPlace cmake/external/onnxruntime_external_deps.cmake \
        --replace-fail "FIND_PACKAGE_ARGS 3.21.12 NAMES Protobuf" \
        "FIND_PACKAGE_ARGS NAMES Protobuf protobuf"
      # Use system Eigen3 instead of FetchContent (backport from ORT 1.20.1)
      cat > cmake/external/eigen.cmake << 'EIGENEOF'
find_package(Eigen3 CONFIG REQUIRED)
get_target_property(eigen_INCLUDE_DIRS Eigen3::Eigen INTERFACE_INCLUDE_DIRECTORIES)
EIGENEOF
      # Disable -Werror for GCC 15 compatibility
      substituteInPlace cmake/CMakeLists.txt \
        --replace-fail "COMPILE_WARNING_AS_ERROR ON" "COMPILE_WARNING_AS_ERROR OFF"
      substituteInPlace onnxruntime/core/platform/env.h \
        --replace-fail "GetRuntimePath() const { return PathString(); }" \
        "GetRuntimePath() const { return PathString(\"$out/lib/\"); }"
    '';

    cmakeFlags = let
      filtered = builtins.filter (f:
        let s = builtins.toString f; in
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_ONNX" s) &&
        !(lib.hasPrefix "-Donnxruntime_BUILD_UNIT_TESTS" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_UTF8_RANGE" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" s) &&
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_PTHREADPOOL" s) &&
        !(lib.hasPrefix "-Donnxruntime_USE_FULL_PROTOBUF" s)
      ) (oldAttrs.cmakeFlags or []);
    in filtered ++ [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" "${onnx-src}")
      (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.5")
      (lib.cmakeBool "onnxruntime_ENABLE_WERROR" false)
      (lib.cmakeBool "CMAKE_COMPILE_WARNING_AS_ERROR" false)
      (lib.cmakeBool "onnxruntime_BUILD_UNIT_TESTS" false)
      (lib.cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true)
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" "${nsync-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_UTF8_RANGE" "${utf8_range-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" "${cpuinfo-src}")
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PTHREADPOOL" "${pthreadpool-src}")
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
      description = "ONNX Runtime CPU-only + ARMv9 (Graviton3+, Grace)";
      platforms = [ "aarch64-linux" ];
    };
  })
