#!/bin/bash

set -euo pipefail

# Define the host key directory inside the container
HOST_KEY_DIR="/etc/ssh/host_keys"
# Define the full paths for the host key files
RSA_KEY="${HOST_KEY_DIR}/ssh_host_rsa_key"
ECDSA_KEY="${HOST_KEY_DIR}/ssh_host_ecdsa_key"
ED25519_KEY="${HOST_KEY_DIR}/ssh_host_ed25519_key"

# Ensure the host key directory exists and has correct permissions.
mkdir -p "$HOST_KEY_DIR"
chmod 700 "$HOST_KEY_DIR"

# Check if RSA key exists; if not, generate all necessary keys
if [ ! -f "$RSA_KEY" ]; then
    echo "--- Generating SSH host keys in ${HOST_KEY_DIR} ---"

    # Generate RSA key
    echo "Generating RSA host key..."
    ssh-keygen -t rsa -f "$RSA_KEY" -N "" || { echo "Failed to generate RSA key."; exit 1; }

    # Generate ECDSA key
    echo "Generating ECDSA host key..."
    ssh-keygen -t ecdsa -f "$ECDSA_KEY" -N "" || { echo "Failed to generate ECDSA key."; exit 1; }

    # Generate ED25519 key
    echo "Generating ED25519 host key..."
    ssh-keygen -t ed25519 -f "$ED25519_KEY" -N "" || { echo "Failed to generate ED25519 key."; exit 1; }

    # Ensure individual private host keys have very restrictive permissions (read-only for root).
    echo "--- Setting permissions for generated host keys ---"
    chmod 600 "$RSA_KEY" "$ECDSA_KEY" "$ED25519_KEY"

    echo "--- Host key generation complete ---"
else
    echo "--- SSH host keys already exist in ${HOST_KEY_DIR} ---"
fi

# Fix ownership/permissions on the borg user's authorized_keys, in case it was
# bind-mounted from the host (sshd's StrictModes will silently reject keys
# with the wrong owner or overly permissive file modes).
AUTHORIZED_KEYS="/home/borg/.ssh/authorized_keys"
if [ -f "$AUTHORIZED_KEYS" ]; then
    echo "--- Fixing permissions on ${AUTHORIZED_KEYS} ---"
    chown borg:borg "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
fi

# Start SSH daemon in foreground mode (-D) and log to stderr (-e).
echo "--- Starting SSH daemon ---"
/usr/sbin/sshd -D -e
