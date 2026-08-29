# atelier-silverblue
## A beginner's guide to customising Fedora Silverblue

### 1. Place the policy files on your Host Machine

Before you run the rebase command, your local Silverblue system needs to know how to verify the image.

Since you are currently booted into a standard system that doesn't have these policies yet, copy your cosign.pub and policy.json configurations directly to your host machine's configuration directories.

    # Create the container PKI folder if it doesn't exist:
    sudo mkdir -p /etc/pki/containers

    # Copy your public key to that directory (run this from your repository root where cosign.pub is located):
    sudo cp cosign/cosign.pub /etc/pki/containers/atelier-silverblue.pub

    # Copy your policy.json to the container configuration folder:
    sudo cp policy.json /etc/containers/policy.json

    # Set up registries.d
    sudo mkdir -p /etc/containers/registries.d
    sudo tee /etc/containers/registries.d/atelier-silverblue.yaml > /dev/null <<'EOF'
    docker:
      ghcr.io/skittle-brau/atelier-silverblue:
        use-sigstore-attachments: true
    EOF

### 2. Perform the Rebase

Now that the policy is active on your host machine, rpm-ostree will read /etc/containers/policy.json, see that ghcr.io/skittle-brau/atelier-silverblue requires a signature, and look for a match using your public key.

Run the rebase command:

    sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/skittle-brau/atelier-silverblue:latest

Note the prefix: We use ostree-image-signed:docker:// to explicitly tell the system to download the container image via the standard container protocol and strictly enforce the local signature policy verification during the pull.

### 3. Reboot to apply

If the command succeeds without errors, it means rpm-ostree successfully verified the GitHub signature against your atelier-silverblue.pub key!

All that's left is to reboot your system to step into your custom, secured deployment:

    systemctl reboot

### What happens next?

From this point forward, your system is locked down. Every time you run rpm-ostree upgrade in the future, your system will securely pull down the new layers, look at the signature on GHCR, check it against your public key, and instantly reject the update if anyone tries to tamper with your container image!
