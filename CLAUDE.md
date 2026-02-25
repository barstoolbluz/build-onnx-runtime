# CLAUDE.md

## Project Overview

This is a Flox-based repository that builds per-architecture ONNX Runtime variants optimized for specific GPU and CPU targets. Each variant is a Nix expression in `.flox/pkgs/` that overrides the nixpkgs `onnxruntime` package with targeted CUDA compute capabilities and CPU instruction sets.

## Common Development Commands

```bash
# Build a specific variant
flox build onnxruntime-python313-cuda12_9-sm90-avx512

# Test the built package
./result-onnxruntime-python313-cuda12_9-sm90-avx512/bin/python -c "import onnxruntime; print(onnxruntime.__version__)"

# Check available providers
./result-onnxruntime-python313-cuda12_9-sm90-avx512/bin/python -c "import onnxruntime; print(onnxruntime.get_available_providers())"

# Publish to catalog
flox publish onnxruntime-python313-cuda12_9-sm90-avx512
```

## Architecture

### Build System
ONNX Runtime uses CMake. The Nix derivations use `.override` + `.overrideAttrs` on the existing nixpkgs `onnxruntime` package — the same pattern as the PyTorch build repo.

Two-layer override:
1. Override C++ `onnxruntime` package for per-arch CMake flags (`cudaSupport`, `CMAKE_CUDA_ARCHITECTURES`, CPU compiler flags)
2. Override `python3Packages.onnxruntime` wrapper to use the custom C++ package, set custom `pname` and `meta`

### Package Naming Convention
```
onnxruntime-python312-cuda12_4[-sm{XX}]-{cpuisa}.nix
onnxruntime-python313-{cuda12_9|cpu}[-sm{XX}]-{cpuisa}.nix
```

CUDA 12.4 variants use Python 3.12; CUDA 12.9 and CPU-only variants use Python 3.13. The CUDA minor version and Python version are encoded in the filename so the exact stack is always visible.

Examples:
- `onnxruntime-python313-cuda12_9-sm90-avx512.nix` (H100 + AVX-512, CUDA 12.9, Python 3.13)
- `onnxruntime-python312-cuda12_4-sm90-avx512.nix` (H100 + AVX-512, CUDA 12.4, Python 3.12)
- `onnxruntime-python313-cpu-avx2.nix` (CPU-only with AVX2, Python 3.13)

### Key Variables Per Variant
- `gpuArchCMake`: CUDA compute capability for `CMAKE_CUDA_ARCHITECTURES` (e.g., `"90"`)
- `cpuFlags`: Compiler optimization flags (e.g., `["-mavx512f" ...]`)
- `variantName`: Package name matching the filename (includes CUDA minor version, e.g., `cuda12_9`)

### Nixpkgs Pin
- Revision: `ed142ab1b3a092c4d149245d0c4126a5d7ea00b0`
- ONNX Runtime: 1.23.2 (CUTLASS 3.9.2 for Blackwell support)
- CUDA: 12.4 via `cudaPackages_12_4` overlay — **requires NVIDIA driver 550+**
- CUDA: 12.9 via `cudaPackages_12_9` overlay — **requires NVIDIA driver 560+**
- Python: 3.13 (CUDA 12.9 + CPU variants), 3.12 (CUDA 12.4 variants)

### Branch Strategy
Branches track ORT versions. The CUDA toolkit version is a property of the branch, documented in README.md, CLAUDE.md, and each `.nix` file header comment.

- **main**: ONNX Runtime 1.23.2 + CUDA 12.4/12.9, driver 550+/560+ (stable)
- **ort-1.24**: ONNX Runtime 1.24.2 + CUDA 12.4/12.9, driver 550+/560+ (current, Blackwell support)
- **ort-1.23**: ONNX Runtime 1.23.2 + CUDA 12.4/12.9, driver 550+/560+ (stable, Blackwell support)
- **ort-1.22**: ONNX Runtime 1.22.2 + CUDA 12.4/12.9, driver 550+/560+ (compat, no Blackwell)
- **ort-1.20**: ONNX Runtime 1.20.1 + CUDA 12.4/12.9, driver 550+/560+ (legacy, no Blackwell)
- **ort-1.19**: ONNX Runtime 1.19.2 + CUDA 12.4/12.9, driver 550+/560+ (legacy, no Blackwell)
- **ort-1.18**: ONNX Runtime 1.18.1 + CUDA 12.4/12.9, driver 550+/560+ (legacy, no Blackwell)

### CUDA Version Documentation
Each GPU `.nix` file includes a two-line header comment:
```nix
# ONNX Runtime 1.23.2 for NVIDIA Hopper (SM90: H100, L40S) + AVX-512
# CUDA 12.9 — Requires NVIDIA driver 560+
```
```nix
# ONNX Runtime 1.23.2 for NVIDIA Hopper (SM90: H100, L40S) + AVX-512
# CUDA 12.4 — Requires NVIDIA driver 550+
```

The `meta.description` also includes the CUDA version:
```nix
description = "ONNX Runtime 1.23.2 for NVIDIA H100/L40S (SM90) + AVX-512 [CUDA 12.9]";
description = "ONNX Runtime 1.23.2 for NVIDIA H100/L40S (SM90) + AVX-512 [CUDA 12.4]";
```

CUDA 12.4 variants use python312Packages.onnxruntime (Python 3.12); CUDA 12.9 and CPU-only variants use python3Packages.onnxruntime (Python 3.13).

## Package Development Guidelines

### Adding a New Variant
1. Copy an existing variant `.nix` file with similar configuration
2. Update `gpuArchCMake`, `cpuFlags`, `variantName`, description, and platform
3. Ensure the header comment includes the ORT version, CUDA version, and driver requirement
4. Ensure `variantName` matches the filename (with `cuda12_4` or `cuda12_9` prefix for GPU variants)
5. Test with `flox build <variant-name>`

### Adding a New CUDA Version
When a new CUDA toolkit is needed (e.g., CUDA 13.0):
1. Create a new branch (e.g., `ort-1.25` if tied to a new ORT release)
2. Update the nixpkgs pin to a revision with the target CUDA version
3. Update the overlay in each GPU `.nix` file (e.g., `cudaPackages_13_0`)
4. Rename GPU files to reflect the new CUDA version (e.g., `cuda13_0`)
5. Update `variantName`, header comments, and `meta.description` in each file
6. Update README.md and CLAUDE.md with the new CUDA version and driver requirement

### Updating ONNX Runtime Version
- Update the nixpkgs pin to a revision with the target ORT version
- All variants share the same pin, so updating it updates all variants
- Update the ORT version in header comments and `meta.description`
- Test a representative GPU and CPU-only variant before committing

## Commit Message Conventions
- Package updates: `<package>: update to latest`
- New packages: `<package>: init`
- Infrastructure changes: Use appropriate prefix (e.g., `workflows:`, `flake:`)
