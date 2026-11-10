#!/usr/bin/env bash
#
# Generates a signing keypair for OpenWrt APK package repository.
#
set -euo pipefail

KEY_NAME="${1:-curl-quic}"
DIR="${2:-.}"

mkdir -p "${DIR}"

PRIV_KEY="${DIR}/${KEY_NAME}.pem"
PUB_KEY="${DIR}/${KEY_NAME}.pub"

echo "=================================================="
echo "Generating OpenWrt APK Signing Keypair (EC prime256v1): ${KEY_NAME}"
echo "=================================================="

# Generate EC prime256v1 private key in PEM format (OpenWrt 25.12+ APK format)
openssl ecparam -name prime256v1 -genkey -noout -out "${PRIV_KEY}"
chmod 600 "${PRIV_KEY}"

# Extract public key in PEM format
openssl ec -in "${PRIV_KEY}" -pubout -out "${PUB_KEY}"

echo ""
echo "Keys generated successfully:"
echo "  Private key: ${PRIV_KEY}"
echo "  Public key:  ${PUB_KEY}"
echo ""
echo "=================================================="
echo "ACTION REQUIRED: Add to GitHub Repository Secrets"
echo "=================================================="
echo "1. Go to your GitHub repository -> Settings -> Secrets and variables -> Actions"
echo "2. Click 'New repository secret'"
echo "3. Name:  APK_PRIVATE_KEY"
echo "4. Value (copy the entire block below including BEGIN and END lines):"
echo ""
cat "${PRIV_KEY}"
echo ""
echo "=================================================="
echo "The public key (${PUB_KEY}) will be placed in /etc/apk/keys/ on your router."
echo "=================================================="
