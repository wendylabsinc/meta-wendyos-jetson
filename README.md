
# WendyOS for NVIDIA Jetson Orin Nano Developer Kit

This repository provides the meta-layer and build flow to build **WendyOS** for the **NVIDIA Jetson Orin Nano Developer Kit**.

## Quick Start

### Prerequisites

- Docker installed and running
- Git
- At least 100GB of free disk space
- Reliable internet connection

### Directory Structure Requirements

**Important**:
The meta-layer repository must be located within or be the working directory where you run the bootstrap script. The bootstrap creates a Docker container that mounts the working directory, so the meta-layer must be accessible within that mount.

Recommended structure:
```
/path/to/project           <- run bootstrap.sh from this folder
  +-- meta-wendyos           <- wendy meta layer repository
  +-- repos                  <- created by bootstrap (Yocto layers)
  +-- build                  <- created by bootstrap (build output)
  +-- docker                 <- created by bootstrap (Docker config)
```

### Steps to Build

1. **Clone the repository** (or place it in your working directory):
   ```bash
   cd /path/to/project
   git clone <repository-url> meta-wendyos
   cd meta-wendyos
   ```

Current repository URL:
 `git@github.com:wendylabsinc/meta-wendyos-jetson.git`

2. **Run the bootstrap script**:
   ```bash
   [EDGEOS_BRANCH=<branch>] ./bootstrap.sh
   ```

   The bootstrap script will:
   - Validate that the meta-layer is within the working directory
   - Clone all required Yocto layers (`poky`, `meta-openembedded`, `meta-tegra`, etc.)
   - Create the `build` directory from configuration meta layer `conf/template` templates
   - Set up the Docker build environment in `docker`
   - Build the Docker image (only if it does not already exist)

3. **Customize build configuration** (optional):

   Edit `build/conf/local.conf` to customize:
   - `DL_DIR` - Download directory for source tarballs (recommended for caching)
   - `SSTATE_DIR` - Shared state cache directory (speeds up rebuilds)
   - `MACHINE` - Target machine configuration:
     - `jetson-orin-nano-devkit-edgeos` (eMMC/SD card boot)
     - `jetson-orin-nano-devkit-nvme-edgeos` (NVMe boot)

4. **Build the image**

   Follow instructions displayed by the `bootstrap.sh`:

   ```bash
   # start the Docker container
   cd ./docker
   ./docker-util.sh run

   # build the Linux image inside the container
   cd ./wendyos
   . ./repos/poky/oe-init-build-env build
   bitbake edgeos-image
   ```

   Depending on the hardware configuration, the build process can take several hours on the first run.

### Flash the SD Card or NVMe

The build produces a flash package at:
```
build/tmp/deploy/images/<machine>/edgeos-image-<machine>.rootfs.tegraflash.tar.gz
```

There are two ways to flash, both using the `dosdcard.sh` script provided by meta-tegra:

#### Option 1: Directly Flash to SD Card

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/<machine>/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./dosdcard.sh /dev/sdX
```

Replace `/dev/sdX` with the actual SD card device (e.g., `/dev/sdb`).

**Warning**: This will erase all data on the device!

#### Option 2: Create a Flashable .img File

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/<machine>/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./dosdcard.sh wendyos
```

This creates `wendyos.img`, which you can flash using:

**Command line:**
```bash
sudo dd if=wendyos.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

**GUI tools:**
- balenaEtcher
- Raspberry Pi Imager
- GNOME Disks

### Available Images

The build produces multiple image formats:
- `tegraflash` - Complete Tegra flash package (bootloader, kernel, rootfs, DTBs)
- `mender` - Mender OTA update artifact (.mender file)
- `dataimg` - Data partition image
- `ext4` - Raw rootfs (for debugging)

## Mender OTA Updates

The system includes Mender for Over-The-Air updates with A/B partition redundancy.

### Partition Layout

**eMMC/SD Card:**
- `/dev/mmcblk0p1` - Root filesystem A
- `/dev/mmcblk0p2` - Root filesystem B
- `/dev/mmcblk0p11` - Boot partition (shared)
- `/dev/mmcblk0p15` - Data partition (persistent)

**NVMe:**
- `/dev/nvme0n1p1` - Root filesystem A
- `/dev/nvme0n1p2` - Root filesystem B
- `/dev/nvme0n1p11` - Boot partition (shared)
- `/dev/nvme0n1p15` - Data partition (persistent)

### Setting Up Mender Server

#### 1. Install Dependencies

```bash
sudo apt install docker.io docker-compose-plugin git
sudo systemctl enable --now docker
```

#### 2. Install Mender Demo Server

```bash
cd <server_dir>
git clone https://github.com/mendersoftware/mender-server
cd mender-server
git checkout v4.0.1
```

#### 3. Configure DNS Resolution

On both the server and all Jetson devices, add the server IP to `/etc/hosts`:

```bash
echo '<server_ip> docker.mender.io s3.docker.mender.io' | sudo tee -a /etc/hosts
```

**Note**: Port `443/tcp` must be open on the server.

#### 4. Start Mender Server

```bash
docker compose up -d

# Create admin user (first run only)
docker compose exec useradm useradm create-user \
  --username "admin@docker.mender.io" \
  --password "password123"
```

#### 5. Verify Server Status

```bash
docker compose ps
docker compose logs -f api-gateway deployments deviceauth
```

### Device Configuration

The Mender client on the Jetson device is pre-configured to connect to `https://docker.mender.io`. Ensure the `/etc/hosts` entry is set (see step 3 above).

The server's TLS certificate is already included in the image at `/etc/mender/server.crt`.

### Deploy an Update

1. Open https://docker.mender.io/ in your browser
2. Log in with `admin@docker.mender.io` / `password123`
3. Go to **Devices → Pending** and accept your Jetson device
4. Upload a `.mender` artifact under **Artifacts**
5. Create a deployment under **Deployments → Create deployment**
6. Monitor the update progress on the device

### Mender Configuration

- **Server URL**: `https://docker.mender.io`
- **Update poll interval**: 30 minutes
- **Inventory poll interval**: 8 hours
- **Artifact naming**: `${IMAGE_BASENAME}-${MACHINE}-${IMAGE_VERSION_SUFFIX}`

### Tear Down Server

```bash
# Stop and remove containers + volumes (wipes all data)
docker compose down -v

# Optional: Remove server files
cd <server_dir>/..
rm -rf mender-server
```

#### Jetson

```bash
$ echo '<mender server IP> docker.mender.io s3.docker.mender.io' | sudo tee -a /etc/hosts
```

The server’s TLS cert for the client to trust (self-signed demo cert!) has to be already present on the device.

#### Mender Web UI

From any browser that resolves the same hostnames (the server should also have the hosts lines):
- Open https://docker.mender.io/ (according to the demo configuration done on both, server and target)
- Log in with the creaged user (e.g., admin@docker.mender.io / password123)
- Go to Devices → Pending and Accept your Jetson
- Upload a .mender artifact under Artifacts, then Deployments → Create deployment


## Advanced Configuration

### Custom Variables in bootstrap.sh

You can modify these variables in `bootstrap.sh` before running:
- `IMAGE_NAME` - Base name for the OS (default: "wendyos")
- `USER_NAME` - Docker container username (default: "dev")
- `YOCTO_BRANCH` - Yocto release branch (default: "scarthgap")

### Build Configuration Variables

In `build/conf/local.conf`:
- `EDGEOS_DEBUG` - Enable debug packages (default: 0)
- `EDGEOS_DEBUG_UART` - Enable UART debug output (default: 0)
- `EDGEOS_USB_GADGET` - Enable USB gadget mode (default: 0)
- `EDGEOS_PERSIST_JOURNAL_LOGS` - Persist logs to storage (default: 0)

## Architecture Notes

- **Yocto Version**: `Scarthgap`
- **Base Layer**: `meta-tegra` (NVIDIA Jetson BSP)
- **Init System**: `systemd`
- **Package Manager**: `RPM`
- **Boot Method**: UEFI with extlinux
- **OTA System**: Mender v5.0.x
- **Display Features**: Removed (headless embedded system)

## License

TBD
