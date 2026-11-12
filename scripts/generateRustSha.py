#!/usr/bin/env python3
"""Download official Rust distribution archives and print their SHA512.

Usage:
    generateRustSha --version 1.98.1 --std        # rust-std-<version>-<target>.tar.gz
    generateRustSha --version 1.98.1 --toolchain  # rust-<version>-<target>.tar.gz

Downloads are cached in a local directory and verified against the official
sha256 checksums (https://static.rust-lang.org/dist/<file>.sha256) before the
SHA512 is computed. Results are printed to stdout as

    <filename>  <sha512>

Missing archives (targets without a distribution, HTTP 404) are reported as
comments at the end. Progress goes to stderr so stdout stays machine readable.
"""

import argparse
import concurrent.futures
import hashlib
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request

DIST_BASE = "https://static.rust-lang.org/dist"

# Host triples that ship a full toolchain distribution archive
# (`rustup toolchain link`-able hosts); rust-<version>-<target>.tar.gz exists
# only for these.
RUSTUP_TOOLCHAIN = [
    "aarch64-apple-darwin",
    "aarch64-pc-windows-gnullvm",
    "aarch64-pc-windows-msvc",
    "aarch64-unknown-freebsd",
    "aarch64-unknown-linux-gnu",
    "aarch64-unknown-linux-musl",
    "aarch64-unknown-linux-ohos",
    "arm-unknown-linux-gnueabi",
    "arm-unknown-linux-gnueabihf",
    "armv7-unknown-linux-gnueabihf",
    "i686-pc-windows-gnu",
    "i686-pc-windows-msvc",
    "i686-unknown-linux-gnu",
    "loongarch64-unknown-linux-gnu",
    "loongarch64-unknown-linux-musl",
    "powerpc-unknown-linux-gnu",
    "powerpc64-unknown-linux-gnu",
    "powerpc64-unknown-linux-musl",
    "powerpc64le-unknown-linux-gnu",
    "powerpc64le-unknown-linux-musl",
    "riscv64gc-unknown-linux-gnu",
    "s390x-unknown-linux-gnu",
    "sparcv9-sun-solaris",
    "x86_64-apple-darwin",
    "x86_64-pc-solaris",
    "x86_64-pc-windows-gnu",
    "x86_64-pc-windows-gnullvm",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-illumos",
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-musl",
]

# All targets known to `rustup target list` (checked out from the Rust
# distribution channel manifest), sorted.
RUSTUP_TARGETS = [
    "aarch64-apple-darwin",
    "aarch64-apple-ios",
    "aarch64-apple-ios-macabi",
    "aarch64-apple-ios-sim",
    "aarch64-apple-tvos",
    "aarch64-apple-tvos-sim",
    "aarch64-apple-visionos",
    "aarch64-apple-visionos-sim",
    "aarch64-apple-watchos",
    "aarch64-apple-watchos-sim",
    "aarch64-linux-android",
    "aarch64-pc-windows-gnullvm",
    "aarch64-pc-windows-msvc",
    "aarch64-unknown-freebsd",
    "aarch64-unknown-fuchsia",
    "aarch64-unknown-linux-gnu",
    "aarch64-unknown-linux-musl",
    "aarch64-unknown-linux-ohos",
    "aarch64-unknown-none",
    "aarch64-unknown-none-softfloat",
    "aarch64-unknown-uefi",
    "arm-linux-androideabi",
    "arm-unknown-linux-gnueabi",
    "arm-unknown-linux-gnueabihf",
    "arm-unknown-linux-musleabi",
    "arm-unknown-linux-musleabihf",
    "arm64ec-pc-windows-msvc",
    "armv5te-unknown-linux-gnueabi",
    "armv5te-unknown-linux-musleabi",
    "armv7-linux-androideabi",
    "armv7-unknown-linux-gnueabi",
    "armv7-unknown-linux-gnueabihf",
    "armv7-unknown-linux-musleabi",
    "armv7-unknown-linux-musleabihf",
    "armv7-unknown-linux-ohos",
    "armv7a-none-eabi",
    "armv7a-none-eabihf",
    "armv7r-none-eabi",
    "armv7r-none-eabihf",
    "armv8r-none-eabihf",
    "i586-unknown-linux-gnu",
    "i586-unknown-linux-musl",
    "i686-linux-android",
    "i686-pc-windows-gnu",
    "i686-pc-windows-gnullvm",
    "i686-pc-windows-msvc",
    "i686-unknown-freebsd",
    "i686-unknown-linux-gnu",
    "i686-unknown-linux-musl",
    "i686-unknown-uefi",
    "loongarch32-unknown-none",
    "loongarch32-unknown-none-softfloat",
    "loongarch64-unknown-linux-gnu",
    "loongarch64-unknown-linux-musl",
    "loongarch64-unknown-none",
    "loongarch64-unknown-none-softfloat",
    "nvptx64-nvidia-cuda",
    "powerpc-unknown-linux-gnu",
    "powerpc64-unknown-linux-gnu",
    "powerpc64-unknown-linux-musl",
    "powerpc64le-unknown-linux-gnu",
    "powerpc64le-unknown-linux-musl",
    "riscv32i-unknown-none-elf",
    "riscv32im-unknown-none-elf",
    "riscv32imac-unknown-none-elf",
    "riscv32imafc-unknown-none-elf",
    "riscv32imc-unknown-none-elf",
    "riscv64a23-unknown-linux-gnu",
    "riscv64gc-unknown-linux-gnu",
    "riscv64gc-unknown-linux-musl",
    "riscv64gc-unknown-none-elf",
    "riscv64imac-unknown-none-elf",
    "s390x-unknown-linux-gnu",
    "sparc64-unknown-linux-gnu",
    "sparcv9-sun-solaris",
    "thumbv6m-none-eabi",
    "thumbv7a-none-eabi",
    "thumbv7a-none-eabihf",
    "thumbv7em-none-eabi",
    "thumbv7em-none-eabihf",
    "thumbv7m-none-eabi",
    "thumbv7neon-linux-androideabi",
    "thumbv7neon-unknown-linux-gnueabihf",
    "thumbv7r-none-eabi",
    "thumbv7r-none-eabihf",
    "thumbv8m.base-none-eabi",
    "thumbv8m.main-none-eabi",
    "thumbv8m.main-none-eabihf",
    "thumbv8r-none-eabihf",
    "wasm32-unknown-emscripten",
    "wasm32-unknown-unknown",
    "wasm32-wasip1",
    "wasm32-wasip1-threads",
    "wasm32-wasip2",
    "wasm32v1-none",
    "x86_64-apple-darwin",
    "x86_64-apple-ios",
    "x86_64-apple-ios-macabi",
    "x86_64-fortanix-unknown-sgx",
    "x86_64-linux-android",
    "x86_64-pc-solaris",
    "x86_64-pc-windows-gnu",
    "x86_64-pc-windows-gnullvm",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-fuchsia",
    "x86_64-unknown-illumos",
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-gnuasan",
    "x86_64-unknown-linux-gnumsan",
    "x86_64-unknown-linux-gnutsan",
    "x86_64-unknown-linux-gnux32",
    "x86_64-unknown-linux-musl",
    "x86_64-unknown-linux-ohos",
    "x86_64-unknown-netbsd",
    "x86_64-unknown-none",
    "x86_64-unknown-redox",
    "x86_64-unknown-uefi",
]


def fetch(url, retries=3, timeout=60):
    """Return the response body as bytes, or None on HTTP 404."""
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pass
        if attempt + 1 < retries:
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"failed to fetch {url}")


def download_file(url, dest):
    """Stream url to dest; return False on HTTP 404."""
    request = urllib.request.Request(url, headers={"User-Agent": "generateRustSha"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response, open(dest + ".part", "wb") as out:
            while True:
                chunk = response.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
    except urllib.error.HTTPError as error:
        if os.path.exists(dest + ".part"):
            os.remove(dest + ".part")
        if error.code == 404:
            return False
        raise
    os.replace(dest + ".part", dest)
    return True


def hash_file(path, algorithm):
    digest = hashlib.new(algorithm)
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def process(target, version, component, cache_dir):
    """Download and hash one archive.

    Returns (filename, sha512) or None when no distribution exists.
    """
    filename = f"{component}-{version}-{target}.tar.gz"
    url = f"{DIST_BASE}/{filename}"
    dest = os.path.join(cache_dir, filename)

    official_sha256 = None
    checksum = fetch(f"{url}.sha256")
    if checksum is not None:
        official_sha256 = checksum.decode("ascii", "replace").split()[0].strip().lower()

    if not os.path.exists(dest):
        if not download_file(url, dest):
            return None

    if official_sha256:
        local_sha256 = hash_file(dest, "sha256")
        if local_sha256 != official_sha256:
            os.remove(dest)
            raise RuntimeError(f"{filename}: sha256 mismatch ({local_sha256} != {official_sha256})")

    return filename, hash_file(dest, "sha512")


def main():
    parser = argparse.ArgumentParser(
        prog="generateRustSha",
        description="Download Rust distribution archives and print filename / SHA512 pairs.",
    )
    parser.add_argument("--version", required=True, help="Rust version, e.g. 1.98.1")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--std", action="store_true", help="hash rust-std-<version>-<target>.tar.gz archives")
    mode.add_argument("--toolchain", action="store_true", help="hash rust-<version>-<target>.tar.gz archives")
    parser.add_argument(
        "--cache-dir",
        default=os.path.join(tempfile.gettempdir(), "rust-dist-cache"),
        help=f"download cache directory (default: {os.path.join(tempfile.gettempdir(), 'rust-dist-cache')})",
    )
    parser.add_argument("--jobs", type=int, default=8, help="concurrent downloads (default: 8)")
    args = parser.parse_args()

    component = "rust-std" if args.std else "rust"
    targets = RUSTUP_TOOLCHAIN if args.toolchain else RUSTUP_TARGETS
    os.makedirs(args.cache_dir, exist_ok=True)

    results = [None] * len(targets)
    errors = []
    done = 0

    def work(index_target):
        return index_target[0], process(index_target[1], args.version, component, args.cache_dir)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(work, item): item for item in enumerate(targets)}
        for future in concurrent.futures.as_completed(futures):
            target = futures[future][1]
            done += 1
            try:
                index, value = future.result()
                results[index] = value
                status = "ok" if value else "missing"
            except Exception as error:  # noqa: BLE001 - report and continue
                errors.append((target, str(error)))
                status = "error"
            print(f"[{done}/{len(targets)}] {target}: {status}", file=sys.stderr, flush=True)

    for result in results:
        if result is not None:
            print(f"{result[1]}  {result[0]}")

    if errors or any(result is None for result in results):
        print("# missing (no distribution archive):")
        for target, result in zip(targets, results):
            if result is None:
                print(f"#   {component}-{args.version}-{target}.tar.gz")
    if errors:
        print("# errors:")
        for target, error in sorted(errors):
            print(f"#   {target}: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
