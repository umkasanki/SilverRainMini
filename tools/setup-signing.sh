#!/bin/bash
# One-time: a stable self-signed code-signing identity for Silver Rain Mini, in a
# dedicated keychain, so that every build — `make install` here and the releases CI
# makes — carries the same signature. macOS ties what it has granted an app (its
# login item approval, later Local Network for AirPlay) to that signature; with
# ad-hoc signing each build is a stranger and the grants start over.
#
#   tools/setup-signing.sh            create the identity (re-runnable: keeps an existing one)
#   tools/setup-signing.sh --secrets  also hand it to GitHub Actions as repo secrets
#
# Why a dedicated keychain (as in AllyClicker and AllyKeyboard): the login keychain
# refuses non-interactive codesign access over SSH; a separate keychain with a known
# throwaway password can be unlocked and partition-listed from the command line.
set -euo pipefail

IDENTITY="SilverRainMini Self-Signed"
KC="$HOME/Library/Keychains/silverrainmini.keychain-db"
KCPASS="silverrainmini"    # throwaway; only guards a self-signed cert
REPO="umkasanki/SilverRainMini"
OPENSSL=/usr/bin/openssl   # LibreSSL: its .p12 is one `security import` reads
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Not `| grep -q`: it quits early and, under pipefail, a found identity reads as missing.
has_identity() { [ -f "$KC" ] && grep -qF "$IDENTITY" <<<"$(security find-identity "$KC" 2>/dev/null)"; }

if has_identity; then
    echo "Identity '$IDENTITY' already exists — keeping it (a new one would reset the grants)."
    security unlock-keychain -p "$KCPASS" "$KC"
else
    echo "[1/5] Generating the certificate..."
    cat > "$TMP/cert.conf" <<CONF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $IDENTITY
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CONF
    $OPENSSL req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.conf" \
        -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
    $OPENSSL pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$IDENTITY" \
        -passout pass:import -out "$TMP/import.p12" >/dev/null 2>&1

    echo "[2/5] Creating the keychain..."
    security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || echo "  (already exists)"
    security unlock-keychain -p "$KCPASS" "$KC"
    security set-keychain-settings "$KC"   # no auto-lock, no lock on sleep

    echo "[3/5] Importing the identity..."
    security import "$TMP/import.p12" -k "$KC" -P import -T /usr/bin/codesign -T /usr/bin/security >/dev/null

    echo "[4/5] Letting codesign use the key without asking..."
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null

    echo "[5/5] Adding the keychain to the search list..."
    EXISTING=$(security list-keychains -d user | sed 's/^[[:space:]]*"//; s/"$//')
    if ! echo "$EXISTING" | grep -qF "silverrainmini.keychain"; then
        # shellcheck disable=SC2086
        security list-keychains -d user -s "$KC" $EXISTING
    fi
    has_identity || { echo "ERROR: '$IDENTITY' is not in $KC after import" >&2; exit 1; }
fi

if [ "${1:-}" = "--secrets" ]; then
    echo "Exporting the identity to the $REPO secrets..."
    PASS="$(uuidgen)"
    security export -k "$KC" -t identities -f pkcs12 -P "$PASS" -o "$TMP/ci.p12"
    base64 -i "$TMP/ci.p12" | gh secret set SIGNING_P12_BASE64 -R "$REPO"
    printf '%s' "$PASS" | gh secret set SIGNING_P12_PASSWORD -R "$REPO"
fi

echo
security find-identity "$KC" | grep -F "$IDENTITY"
echo "Done. \`make install\` now signs as '$IDENTITY'."
[ "${1:-}" = "--secrets" ] || echo "For releases: tools/setup-signing.sh --secrets"
