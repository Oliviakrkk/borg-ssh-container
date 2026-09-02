# Ubuntu 26.04 LTS, pinned by digest for reproducible builds.
# Dependabot keeps this updated (see .github/dependabot.yml).
FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

# Update apt-get and install necessary packages: openssh-server and borgbackup
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server borgbackup && \
    # Clean up apt cache to reduce image size
    rm -rf /var/lib/apt/lists/*

# Create the 'borg' user, set its home directory, and assign a bash shell
RUN useradd -m -d /home/borg -s /bin/bash borg && \
    # Create .ssh directory for the borg user
    mkdir -p /home/borg/.ssh && \
    # Set appropriate ownership for the borg user's home directory and .ssh
    chown -R borg:borg /home/borg && \
    # Set restrictive permissions for .ssh directory
    chmod 700 /home/borg/.ssh

# Explicitly create and set permissions for /run/sshd during the build process.
# This ensures it's ready before sshd attempts to use it at runtime.
RUN mkdir -p /run/sshd && chmod 0755 /run/sshd

# Configure SSH daemon:
# Disable password authentication for enhanced security (key-only access)
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    # Prevent root login via SSH
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Create the new directory for host keys inside the container
RUN mkdir -p /etc/ssh/host_keys && chmod 700 /etc/ssh/host_keys
# Add HostKey directives to sshd_config pointing to the new directory
# This explicitly tells sshd where to find its host keys.
RUN echo "HostKey /etc/ssh/host_keys/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /etc/ssh/host_keys/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /etc/ssh/host_keys/ssh_host_ed25519_key" >> /etc/ssh/sshd_config

# Copy the start-sshd.sh script into the container
COPY start-sshd.sh /start-sshd.sh
# Make the script executable
RUN chmod +x /start-sshd.sh

# Expose port 22 for SSH connections
EXPOSE 22

# Consider sshd unhealthy if it stops accepting TCP connections on port 22.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD bash -c '</dev/tcp/127.0.0.1/22' || exit 1

# Set the entrypoint to run the start-sshd.sh script
CMD ["/start-sshd.sh"]
