# ONNX Runtime 1.22.2 CPU-only + AVX-512 VNNI
{ pkgs ? import <nixpkgs> {} }:
let
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0.tar.gz";
  }) {
    config = { allowUnfree = true; };
  };
  inherit (nixpkgs_pinned) lib fetchFromGitHub;

  # ── Variant-specific configuration ──────────────────────────────────
  cpuFlags = [ "-mavx512f" "-mavx512dq" "-mavx512vl" "-mavx512bw" "-mavx512vnni" "-mfma" ];
  variantName = "onnxruntime-python313-cpu-avx512vnni";
  # ────────────────────────────────────────────────────────────────────

  # ── ORT 1.22.2 source override ─────────────────────────────────────
  ortVersion = "1.22.2";
  ortSrc = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    tag = "v${ortVersion}";
    fetchSubmodules = true;
    hash = "sha256-X8Pdtc0eR0iU+Xi2A1HrNo1xqCnoaxNjj4QFm/E3kSE=";
  };
  onnx-src = fetchFromGitHub {
    name = "onnx-src";
    owner = "onnx";
    repo = "onnx";
    tag = "v1.17.0";
    hash = "sha256-9oORW0YlQ6SphqfbjcYb0dTlHc+1gzy9quH/Lj6By8Q=";
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
      substituteInPlace onnxruntime/core/platform/env.h \
        --replace-fail "GetRuntimePath() const { return PathString(); }" \
        "GetRuntimePath() const { return PathString(\"$out/lib/\"); }"
    '';

    cmakeFlags = let
      filtered = builtins.filter (f:
        let s = builtins.toString f; in
        !(lib.hasPrefix "-DFETCHCONTENT_SOURCE_DIR_ONNX" s)
      ) (oldAttrs.cmakeFlags or []);
    in filtered ++ [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" "${onnx-src}")
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
      description = "ONNX Runtime CPU-only + AVX-512 VNNI";
      platforms = [ "x86_64-linux" ];
    };
  })
