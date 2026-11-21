#!/bin/bash
# Build the it87 kernel module package for one unRAID kernel.
# Usage: build-kmod.sh <unraid kernel src dir, e.g. .../src/linux-6.18.64-Unraid> <output dir>
# The src dir comes from unRAID's bzmodules (config, *.patch, drivers/).
# Package layout matches ich777's packages (kernel/drivers/hwmon + plugin icon).
set -euo pipefail

UNRAID_SRC="$(cd "$1" && pwd)"
OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$(mktemp -d)}"
DRIVER_REPO="${DRIVER_REPO:-https://github.com/frankcrawford/it87}"
DRIVER_REF="${DRIVER_REF:-master}"
PACKAGE="it87"

KREL="$(basename "$UNRAID_SRC" | sed 's/^linux-//')"
KVER="${KREL%%-*}"
echo "Building ${PACKAGE} for kernel ${KREL}"

# vanilla kernel + unRAID patches and config
cd "$WORK_DIR"
curl -sfL "https://cdn.kernel.org/pub/linux/kernel/v${KVER%%.*}.x/linux-${KVER}.tar.xz" | tar -xJ
cd "linux-${KVER}"
cp -r "$UNRAID_SRC/drivers/." drivers/
for p in "$UNRAID_SRC"/*.patch; do
  patch -p1 -s < "$p"
done
cp "$UNRAID_SRC/config" .config
make -s olddefconfig
make -s -j"$(nproc)" modules_prepare
if [ "$(make -s kernelrelease)" != "$KREL" ]; then
  echo "kernelrelease $(make -s kernelrelease) does not match ${KREL}" >&2
  exit 1
fi

# driver module (full clone: the Makefile derives the module version from git describe)
cd "$WORK_DIR"
git clone -q "$DRIVER_REPO" driver
git -C driver checkout -q "$DRIVER_REF"
DRIVER_VERSION="$(git -C driver log -1 --format=%cs | sed 's/-//g')"
# no Module.symvers without a full kernel build; fine as unRAID has CONFIG_MODVERSIONS off
make -s -C "$WORK_DIR/driver" KERNEL_BUILD="$WORK_DIR/linux-${KVER}" KBUILD_MODPOST_WARN=1 modules
if ! modinfo -F vermagic "$WORK_DIR/driver/it87.ko" | grep -q "^${KREL} "; then
  echo "vermagic does not match ${KREL}" >&2
  exit 1
fi
# the plugin checks for this parameter to tell the frankcrawford module from the in-kernel one
modinfo -F parm "$WORK_DIR/driver/it87.ko" | grep -q "^mmio:" || { echo "mmio parameter missing" >&2; exit 1; }

# slackware package
PKG_DIR="$WORK_DIR/pkg"
MOD_DIR="$PKG_DIR/lib/modules/${KREL}/kernel/drivers/hwmon"
mkdir -p "$MOD_DIR" "$PKG_DIR/usr/local/emhttp/plugins/it87-driver/images" "$PKG_DIR/install"
cp "$WORK_DIR/driver/it87.ko" "$MOD_DIR/"
xz --check=crc32 --lzma2 "$MOD_DIR/it87.ko"
cp "$REPO_DIR/images/it87-driver.png" "$PKG_DIR/usr/local/emhttp/plugins/it87-driver/images/"
cat > "$PKG_DIR/install/slack-desc" <<EOF
       |-----handy-ruler------------------------------------------------------|
${PACKAGE}: ${PACKAGE}
${PACKAGE}:
${PACKAGE}:
${PACKAGE}: Custom ${PACKAGE} package for Unraid Kernel v${KVER}
${PACKAGE}: Source: ${DRIVER_REPO}
${PACKAGE}:
EOF
find "$PKG_DIR" -type d -exec chmod 755 {} +
find "$PKG_DIR" -type f -exec chmod 644 {} +
PKG_NAME="${PACKAGE}-${DRIVER_VERSION}-${KREL}-1.txz"
tar --owner=0 --group=0 --sort=name --xform='sx^\./\(.\)x\1x' -C "$PKG_DIR" -cJf "$OUT_DIR/$PKG_NAME" .
(cd "$OUT_DIR" && md5sum "$PKG_NAME" | awk '{print $1}' > "$PKG_NAME.md5")
echo "$OUT_DIR/$PKG_NAME"
