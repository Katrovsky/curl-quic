# curl-quic for OpenWrt

Automated build system and package repository for compiling `curl` with native HTTP/3 and QUIC support as an APK package for OpenWrt 25.12+ (`aarch64_cortex-a53`).

Tested and verified on OpenWrt 25.12.6 (`mediatek/filogic`):
- `curl 8.23.0`
- `quictls 3.1.5`
- `ngtcp2 1.11.0`
- `nghttp3 1.8.0`

---

## Technical Overview

### Problem Statement
Standard OpenWrt packages provide `curl` compiled with mbedTLS or basic OpenSSL without QUIC capabilities. OpenSSL versions bundled in OpenWrt do not expose the required QUIC transport APIs (`SSL_set_quic_use_legacy_codepoint`, etc.). Replacing system `libssl` with a custom fork often causes ABI incompatibilities, breaking core system services (`uhttpd`, `luci`, `dnsmasq`, `wpad`).

### Architectural Solution
This project compiles `quictls`, `nghttp3`, and `ngtcp2` as static libraries and statically links them into the `curl` binary:
- **No System Library Conflicts:** The binary does not replace or depend on `/usr/lib/libssl.so*` or `/usr/lib/libcrypto.so*`.
- **Zero Symbol Clashes:** Eliminates `SSL_set_quic_use_legacy_codepoint: symbol not found` relocation errors.
- **Minimal Footprint:** Dynamic dependencies are limited to system `libc` (`musl`). Stripped binary size is approximately 3.5 MB.
- **Drop-in Integration:** The package defines `PROVIDES:=curl` and installs `/usr/bin/curl` and `/usr/bin/curl-quic`.

---

## Installation on OpenWrt

### Method 1: Via APK Repository (Recommended)

1. Import the repository public signing key:
   ```sh
   wget -O /etc/apk/keys/curl-quic.pub https://katrovsky.github.io/curl-quic/curl-quic.pub
   ```

2. Add the repository to apk package sources:
   ```sh
   echo "https://katrovsky.github.io/curl-quic/aarch64_cortex-a53/packages.adb" > /etc/apk/repositories.d/curl-quic.list
   ```

3. Update the package database and install:
   ```sh
   apk update
   apk add curl-quic
   ```

### Method 2: Manual Installation from GitHub Releases

1. Download the latest `.apk` package from [Releases](https://github.com/Katrovsky/curl-quic/releases).
2. Transfer to router and install:
   ```sh
   apk add --allow-untrusted /tmp/curl-quic_8.23.0-1_aarch64_cortex-a53.apk
   ```

---

## Verification

Check version and compiled features:
```sh
curl --version
```

Expected output:
```text
curl 8.23.0 (aarch64-openwrt-linux-gnu) libcurl/8.23.0 quictls/3.1.5 ngtcp2/1.11.0 nghttp3/1.8.0
Release-Date: 2026-10-14
Protocols: file ftp ftps http https ipfs ipns mqtt mqtts ws wss
Features: alt-svc AsynchDNS HSTS HTTP3 HTTPS-proxy IPv6 Largefile SSL threadsafe UnixSockets
```

Verify HTTP/3 connectivity:
```sh
curl --http3 -I https://cloudflare-quic.com
```

Expected response:
```text
HTTP/3 200
date: ...
content-type: text/html
server: cloudflare
alt-svc: h3=":443"; ma=86400
```

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build.yml`):
1. Downloads the official OpenWrt SDK for the specified target and release (dynamically resolving GCC toolchain archives via `sha256sums`).
2. Compiles static QuicTLS, nghttp3, ngtcp2, and cURL.
3. Packages the output into an APK (`curl-quic_<ver>_aarch64_cortex-a53.apk`).
4. Generates and signs `packages.adb` and `APKINDEX.tar.gz` using the repository private key (`APK_PRIVATE_KEY` secret).
5. Deploys the repository to GitHub Pages (`/aarch64_cortex-a53/packages.adb`, `*.apk`, `curl-quic.pub`).
6. Attaches release packages to GitHub Releases for tagged builds (`v*`).

### Manual Workflow Dispatch

The workflow supports manual execution with custom parameters:

| Input | Description | Default |
|---|---|---|
| `openwrt_version` | OpenWrt release version | `25.12.6` |
| `target` | Platform target family | `mediatek` |
| `subtarget` | Platform subtarget | `filogic` |
| `arch` | Architecture identifier | `aarch64_cortex-a53` |

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── build.yml          # GitHub Actions CI/CD workflow
├── package/
│   └── curl-quic/
│       ├── Makefile           # OpenWrt package recipe
│       └── build-bundle.sh    # Static cross-compilation script
├── scripts/
│   ├── generate-keys.sh       # EC prime256v1 signing keypair generator
│   └── build-local.sh         # Local Docker-based test build runner
├── curl-quic.pub              # Public signing key for /etc/apk/keys/
├── index.html                 # GitHub Pages repository landing page
├── .gitattributes             # Enforced LF line endings
├── .gitignore
└── README.md
```

---

## Security and Key Management

- The repository index is cryptographically signed using an EC `prime256v1` ECDSA key (OpenWrt 25.12+ APK format).
- The private signing key is stored exclusively as a GitHub Actions repository secret (`APK_PRIVATE_KEY`).
- The public key is distributed as `curl-quic.pub` and installed into `/etc/apk/keys/` on the router.

---

## License

MIT. cURL is distributed under the curl license.
