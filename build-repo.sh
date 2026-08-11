#!/usr/bin/env bash
# Build the orbit apt repository layout.
#
# Produces, in the current directory:
#   pool/main/{optix,orbiter,realspeed-cli,orbit-status}/*.deb
#   dists/stable/main/binary-amd64/{Packages,Packages.gz}
#   dists/stable/Release + InRelease (signed)
#
# Push the resulting tree to the `gh-pages` branch of the orbit-apt repo to
# serve it over HTTPS (the `InRelease` signature makes `[trusted=yes]` optional).
set -euo pipefail

SUITE=stable
DIST=main
ARCH=amd64
KEY=0AE41B48AFD3A8CA
POOL=pool/main
DISTS=dists/$SUITE/$DIST/binary-$ARCH

rm -rf pool dists
mkdir -p "$POOL" "$DISTS"

for deb in "$@"; do
    [ -f "$deb" ] || { echo "missing: $deb" >&2; exit 1; }
    pkg=$(dpkg-deb -f "$deb" Package)
    ver=$(dpkg-deb -f "$deb" Version | tr ':' '-')
    arch=$(dpkg-deb -f "$deb" Architecture)
    mkdir -p "$POOL/$pkg"
    cp "$deb" "$POOL/$pkg/${pkg}_${ver}_${arch}.deb"
done

# Index: Packages + Packages.gz for the archive.
apt-ftparchive packages "$POOL" > "$DISTS/Packages"
gzip -9 -kf "$DISTS/Packages"

# Release file with hashes, then a detached signature for InRelease.
apt-ftparchive release -o APT::FTPArchive::Release::Origin=orbit \
    -o APT::FTPArchive::Release::Label=orbit \
    -o APT::FTPArchive::Release::Suite=$SUITE \
    -o APT::FTPArchive::Release::Codename=$SUITE \
    -o APT::FTPArchive::Release::Architectures=$ARCH \
    -o APT::FTPArchive::Release::Components=$DIST \
    dists/$SUITE > dists/$SUITE/Release

gpg --batch --yes --armor --detach-sign --digest-algo SHA512 \
    --local-user "$KEY" --output dists/$SUITE/Release.gpg dists/$SUITE/Release
# InRelease is the Release content + inline armor, what apt actually verifies.
gpg --batch --yes --clearsign --digest-algo SHA512 \
    --local-user "$KEY" --output dists/$SUITE/InRelease dists/$SUITE/Release

# Export the public key for users to install into their keyring.
gpg --batch --yes --armor --export "$KEY" > orbit-archive-keyring.asc

echo "Repo built:"
find pool dists -type f | sort
