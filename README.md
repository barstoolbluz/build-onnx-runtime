# ONNX Runtime Custom Build Environment

> **You are on the `ort-1.24` branch** — ONNX Runtime 1.24.2 + CUDA 12.4/12.9 + Driver 550+/560+ (66 variants)

This Flox environment builds custom ONNX Runtime variants with targeted optimizations for specific GPU architectures and CPU instruction sets.

## Branch Strategy

Each branch tracks a specific ONNX Runtime version. The CUDA toolkit version and minimum driver requirement are properties of the branch, documented here and in each `.nix` file header.

| Branch | ORT Version | CUDA | Min Driver | Status |
|--------|-------------|------|------------|--------|
| `main` | 1.23.2 | 12.4, 12.9 | 550+/560+ | Stable |
| `ort-1.24` | 1.24.2 | 12.4, 12.9 | 550+/560+ | Current |
| `ort-1.23` | 1.23.2 | 12.4, 12.9 | 550+/560+ | Stable |
| `ort-1.22` | 1.22.2 | 12.4, 12.9 | 550+/560+ | Compat |
| `ort-1.20` | 1.20.1 | 12.4, 12.9 | 550+/560+ | Legacy |
| `ort-1.19` | 1.19.2 | 12.4, 12.9 | 550+/560+ | Legacy |
| `ort-1.18` | 1.18.1 | 12.4, 12.9 | 550+/560+ | Legacy |

To use a different ORT version, check out the corresponding branch. All variants on a branch share the same ORT version, CUDA toolkit, and nixpkgs pin.

## CUDA Compatibility

GPU variants on this branch are available in two CUDA toolkit versions:

- **CUDA 12.4 + Python 3.12** — requires **NVIDIA driver 550+** (R550 production branch, widely deployed in GPU serving fleets)
- **CUDA 12.9 + Python 3.13** — requires **NVIDIA driver 560+** (latest toolkit features)

Choose CUDA 12.4 variants for maximum deployment compatibility, or CUDA 12.9 for the latest toolkit.

- **Forward compatibility**: Builds work with any driver that supports the target CUDA version or later
- **No cross-major compatibility**: CUDA 12.x builds are **not** compatible with CUDA 11.x or 13.x runtimes
- **Check your driver**: Run `nvidia-smi` — the "CUDA Version" in the top-right shows the maximum CUDA version your driver supports

```bash
# Verify your driver supports your target CUDA version
nvidia-smi
# Look for "CUDA Version: 12.4" or higher (for cuda12_4 variants)
# Look for "CUDA Version: 12.9" or higher (for cuda12_9 variants)
```

## Overview

Standard ONNX Runtime wheels from PyPI compile kernels for all CUDA compute capabilities and generic x86-64 CPU instructions. This project creates **per-architecture builds** from source, resulting in:

- **Smaller binaries** — Only include CUDA kernels for your target GPU architecture
- **Better CPU inference** — INT8/VNNI paths with hand-optimized per-arch intrinsics
- **Targeted deployment** — Install exactly what your hardware needs
- **AOT-compiled kernels** — All C++ kernels compiled ahead of time (unlike JAX's JIT approach)

## Version Matrix

| Component | Version | Min Driver | Notes |
|-----------|---------|------------|-------|
| ONNX Runtime | 1.24.2 | — | From source via CMake (version override on nixpkgs 1.23.2 base) |
| CUTLASS | 4.2.1 | — | Bundled, Blackwell support |
| ONNX | 1.20.1 | — | Bundled via `FETCHCONTENT_SOURCE_DIR_ONNX` |
| abseil-cpp | 20250814.0 | — | Bundled via `FETCHCONTENT_SOURCE_DIR_ABSEIL_CPP` |
| CUDA Toolkit | 12.4 | 550+ | Via nixpkgs `cudaPackages_12_4` |
| CUDA Toolkit | 12.9 | 560+ | Via nixpkgs `cudaPackages_12_9` |
| Python | 3.13 | — | Via nixpkgs (CUDA 12.9 + CPU variants) |
| Python | 3.12 | — | Via nixpkgs (CUDA 12.4 variants) |
| Nixpkgs | [`ed142ab`](https://github.com/NixOS/nixpkgs/tree/ed142ab1b3a092c4d149245d0c4126a5d7ea00b0) | — | Pinned revision |

## Build Matrix

### GPU Variants (7 architectures x 4 x86 ISAs + 2 SM90 ARM = 30 per CUDA version, 60 total)

| SM | Architecture | GPUs | x86 ISAs | ARM ISAs |
|----|-------------|------|----------|----------|
| SM75 | Turing | T4, RTX 2080 Ti | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |
| SM80 | Ampere DC | A100, A30 | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |
| SM86 | Ampere | RTX 3090, A40 | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |
| SM89 | Ada | RTX 4090, L4, L40 | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |
| SM90 | Hopper | H100, L40S, Grace Hopper | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | ARMv8.2, ARMv9 |
| SM100 | Blackwell DC | B100, B200 | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |
| SM120 | Blackwell | RTX 5090 | AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI | — |

### CPU-only Variants (6)

| ISA | Flags | Hardware | Platform |
|-----|-------|----------|----------|
| AVX2 | `-mavx2 -mfma` | Haswell+ (2013+) | x86_64-linux |
| AVX-512 | `-mavx512f -mavx512dq -mavx512vl -mavx512bw -mfma` | Skylake-X+ (2017+) | x86_64-linux |
| AVX-512 BF16 | AVX-512 + `-mavx512bf16` | Cooper Lake+ (2020+) | x86_64-linux |
| AVX-512 VNNI | AVX-512 + `-mavx512vnni` | Ice Lake+ INT8 inference | x86_64-linux |
| ARMv8.2 | `-march=armv8.2-a+fp16+dotprod` | Graviton2 | aarch64-linux |
| ARMv9 | `-march=armv9-a+sve2` | Graviton3+, Grace | aarch64-linux |

### Total: 66 variants (60 GPU + 6 CPU-only)

## Quick Start

```bash
# Build a specific variant (CUDA 12.9)
flox build onnxruntime-python313-cuda12_9-sm90-avx512

# Build a specific variant (CUDA 12.4 — driver 550+)
flox build onnxruntime-python312-cuda12_4-sm90-avx512  # Python 3.12

# The output is in result-<variant-name>/
# Test it
./result-onnxruntime-python313-cuda12_9-sm90-avx512/bin/python -c "import onnxruntime; print(onnxruntime.__version__)"

# Check providers
./result-onnxruntime-python313-cuda12_9-sm90-avx512/bin/python -c "import onnxruntime; print(onnxruntime.get_available_providers())"
```

## Variant Selection Guide

**Which GPU variant do I need?**
- H100, H200, L40S → `sm90`
- RTX 4090, L4, L40 → `sm89`
- A100, A30 → `sm80`
- RTX 3090, A40 → `sm86`
- T4, RTX 2080 Ti → `sm75`
- B100, B200 → `sm100`
- RTX 5090 → `sm120`

**Which CPU ISA do I need?**
- Most modern x86-64 servers → `avx512`
- Older hardware or broad compatibility → `avx2`
- BF16 training focus → `avx512bf16`
- INT8 inference focus → `avx512vnni`
- AWS Graviton2 → `armv8_2`
- AWS Graviton3+, NVIDIA Grace → `armv9`

## Naming Convention

```
onnxruntime-python312-cuda12_4[-sm{XX}]-{cpuisa}
onnxruntime-python313-{cuda12_9|cpu}[-sm{XX}]-{cpuisa}
```

CUDA 12.4 variants use Python 3.12; CUDA 12.9 and CPU-only variants use Python 3.13.
The CUDA minor version is encoded in the filename so the exact toolkit version is always visible.

## Build Architecture

ONNX Runtime uses CMake. The Nix derivations use `.override` + `.overrideAttrs` on the existing nixpkgs `onnxruntime` package:

1. **C++ override**: Sets `cudaSupport`, `pythonSupport`, `CMAKE_CUDA_ARCHITECTURES`, and CPU compiler flags
2. **Python wrapper override**: Uses the custom C++ package, sets variant-specific `pname` and `meta`

### Key Differences from PyTorch Builds

| Aspect | PyTorch | ONNX Runtime |
|--------|---------|--------------|
| Build system | CMake + Ninja | CMake |
| GPU targeting | `TORCH_CUDA_ARCH_LIST` | `CMAKE_CUDA_ARCHITECTURES` |
| CPU targeting | `CXXFLAGS` | `CXXFLAGS` |
| Override pattern | `.override` + `.overrideAttrs` | `.override` + `.overrideAttrs` |
| Kernel type | AOT C++ | AOT C++ |

### Key Differences from jaxlib Builds

| Aspect | jaxlib | ONNX Runtime |
|--------|--------|--------------|
| Build system | Bazel (two-phase FOD) | CMake (single phase) |
| Kernel compilation | JIT via XLA | AOT C++ |
| Per-arch benefit | Limited (JIT recompiles) | High (AOT intrinsics) |

## Build Requirements

- ~15GB disk space per variant
- 8GB+ RAM (16GB+ recommended for CUDA builds)
- CUDA builds use `requiredSystemFeatures = [ "big-parallel" ]`

## License

Build configuration: MIT
ONNX Runtime: MIT
