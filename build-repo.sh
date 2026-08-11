#!/usr/bin/env bash
# Build (or update) the orbit apt repository layout.
#
# Layout produced/updated in the current directory:
#   pool/main/{pkg}/*.deb            — newest version kept per package
#   dists/stable/main/binary-amd64/{Packages,Packages.gz}
#   dists/stable/Release + InRelease (signed)
#
# Run from a checkout of the `gh-pages` branch so existing packages are kept;
# new .debs passed as arguments are added and old versions pruned. Re-run the
# script with fresh .debs to publish updates.
#
# The `InRelease` signature makes `[trusted=yes]` unnecessary for users.
set -euo pipefail

SUITE=stable
DIST=main
ARCH=amd64
KEY=0AE41B48AFD3A8CA
POOL=pool/main
DISTS=dists/$SUITE/$DIST/binary-$ARCH

mkdir -p "$POOL" "$DISTS"

# Add (or replace) the .debs handed to us.
for deb in "$@"; do
    [ -f "$deb" ] || { echo "missing: $deb" >&2; exit 1; }
    pkg=$(dpkg-deb -f "$deb" Package)
    ver=$(dpkg-deb -f "$deb" Version | tr ':' '-')
    arch=$(dpkg-deb -f "$deb" Architecture)
    mkdir -p "$POOL/$pkg"
    cp "$deb" "$POOL/$pkg/${pkg}_${ver}_${arch}.deb"
done

# Prune old versions: keep only the newest .deb per package.
for dir in "$POOL"/*; do
    [ -d "$dir" ] || continue
    newest=""
    for f in "$dir"/*.deb; do
        [ -f "$f" ] || continue
        if [ -z "$newest" ]; then
            newest="$f"
        elif dpkg --compare-versions "$(dpkg-deb -f "$f" Version)" gt "$(dpkg-deb -f "$newest" Version)"; then
            newest="$f"
        fi
    done
    [ -n "$newest" ] || continue
    for f in "$dir"/*.deb; do
        [ "$f" != "$newest" ] && rm -f "$f"
    done
done

# Index: Packages + Packages.gz for the archive.
apt-ftparchive packages "$POOL" > "$DISTS/Packages"
gzip -9 -kf "$DISTS/Packages"

# Release file with hashes, then signatures for InRelease.
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

echo "Repo updated:"
find pool dists -type f | sort
