# vcpkg-overlay

This repository extends [vcpkg](https://github.com/microsoft/vcpkg): it provides
user-defined ports, toolchains and triplets, together with three functionally
identical deploy scripts (bash / batch / PowerShell) that deploy everything into
any vcpkg installation root in one shot, and can fully undo the deployment with
`--restore`.

## Repository Layout

```
ports/                          Custom ports (overlay ports)
├── ck                          C99 concurrency primitives / lock-free data structures
├── corrosion                   Rust <-> CMake integration module
├── cppcommon                   Common C++ utility library
├── cppserver                   Async C++ networking library on Asio/OpenSSL
├── poco                        POCO C++ libraries (patched port)
├── slint                       Slint C++ GUI runtime
├── vcpkg-cargo                 Cargo build helper port (vcpkg_cargo_* functions)
├── vcpkg-tool-rust             Rust toolchain port (rustc/cargo/std -> tools/rust)
├── zenoh-c                     Zenoh C API
└── zenoh-cpp                   Zenoh C++ API (header-only)
toolchains/
└── amd-linux.cmake             Cross-compilation toolchain for Linux on AMD targets
                                (arm/x86/x64/arm64/riscv64, supports Yocto
                                OECORE_NATIVE_SYSROOT)
triplets/community/
├── arm-amd-linux.cmake         ARM Linux triplet (static libraries)
└── arm-amd-linux-dynamic.cmake ARM Linux triplet (dynamic libraries)
scripts/
└── generateRustSha.py          Maintenance tool for Rust distribution SHA512 hashes
test/                           Tests (see "Tests" below)
deploy-overlay.sh               Deploy script (Linux / macOS, bash)
deploy-overlay.bat              Deploy script (Windows, cmd)
deploy-overlay.ps1              Deploy script (Windows, PowerShell)
```

## Deploy and Restore

The three scripts implement the same functionality; pick whichever matches your
shell.

### Usage

```sh
# Linux / macOS
./deploy-overlay.sh --vcpkg-root <path> [--restore]
```

```bat
:: Windows (cmd)
deploy-overlay.bat --vcpkg-root <path> [--restore]
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root <path> [--restore]
```

### Options

| Option | Description |
| --- | --- |
| `--vcpkg-root <path>` | vcpkg installation root (required). When omitted the script exits with an error asking you to install vcpkg first; the directory must contain `scripts/toolchains`, otherwise it is rejected as a valid vcpkg root |
| `--restore` | Restore mode: deletes every file copied during deployment, renames `*.origin` back to the original file names, and removes directories that became empty |
| `-h` / `--help` | Show help |

### What Gets Deployed

| Repository directory | Deployed to |
| --- | --- |
| `ports/` | `<vcpkg-root>/overlay/ports` |
| `toolchains/` | `<vcpkg-root>/scripts/toolchains` |
| `triplets/` | `<vcpkg-root>/triplets` |

Directories are merged recursively; existing unrelated content in the target is
left untouched (e.g. the community triplets already present in
`triplets/community/` stay as they are).

### Name-Conflict Handling

- When a deployed file collides with an existing one, the original file is first
  renamed to `<file-name>.origin`, then the new file is written;
- `--restore` deletes the copied files and renames `<file-name>.origin` back to
  `<file-name>`;
- Safety guard: if `*.origin` backups from a previous deployment are still
  present (i.e. the previous deployment was never restored, and redeploying
  would mistake the second-generation copies for originals), the script refuses
  to deploy and asks you to run `--restore` first.

### Exit Codes

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | `--vcpkg-root` not specified, invalid vcpkg root, unrestored previous deployment detected, copy/delete failure |
| `2` | Bad arguments (unknown option, missing value for `--vcpkg-root`) |

## Using vcpkg After Deployment

```sh
# Install from the overlay ports (classic mode)
vcpkg install zenoh-cpp --overlay-ports=<vcpkg-root>/overlay/ports

# Use a custom triplet (deployed to <vcpkg-root>/triplets/community, visible to
# vcpkg automatically). The triplet locates the toolchain through the VCPKG_ROOT
# environment variable and chainloads
# <VCPKG_ROOT>/scripts/toolchains/amd-linux.cmake automatically.
export VCPKG_ROOT=/path/to/vcpkg
vcpkg install ck:arm-amd-linux --overlay-ports=$VCPKG_ROOT/overlay/ports
```

In manifest mode, point `"overlay-ports"` in `vcpkg-configuration.json` at
`<vcpkg-root>/overlay/ports` for the same effect.

## Tests

```sh
# Cross-validation matrix for the deploy scripts: {sh, bat, ps1} deploy x
# {sh, bat, ps1} restore, 9 combinations in total. Each cell verifies the
# deployed content, the preserved *.origin originals, and that the tree is
# byte-identical to its pre-deploy state after restore.
./test/cross-test.sh <vcpkg-root>

# zenoh-cpp end-to-end test (install -> build -> run a pub/sub round trip)
./test/run-test.sh                                             # Linux / macOS
powershell -ExecutionPolicy Bypass -File test/run-test.ps1     # Windows
```

The remaining test projects (`test/zenoh-demo`, `test/slint-demo`,
`test/cargo-smoke`) are driven by the scripts above or by the instructions in
their own directories.

## SHA512 Maintenance Tool

The hash table of official Rust distribution archives referenced by the
`vcpkg-tool-rust` port is maintained with `scripts/generateRustSha.py`:

```sh
python scripts/generateRustSha.py --version 1.98.1 --std        # rust-std archives
python scripts/generateRustSha.py --version 1.98.1 --toolchain  # host toolchain archives
```

## License

[MIT](LICENSE)
