
# WendyOS for NVIDIA Jetson Orin Nano Developer Kit

This repository provides the meta-layer and build flow to build **WendyOS** for the **NVIDIA Jetson Orin Nano Developer Kit**.

## Table of Contents

- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [Directory Structure Requirements](#directory-structure-requirements)
  - [Steps to Build](#steps-to-build)
  - [Flash the SD Card or NVMe](#flash-the-sd-card-or-nvme)
  - [Available Images](#available-images)
- [Mender OTA Updates](#mender-ota-updates)
  - [Partition Layout](#partition-layout)
  - [Manual Update](#manual-update)
  - [Mender Server Update](#mender-server-update)
    - [Setting Up Mender Server](#setting-up-mender-server)
    - [Device Configuration](#device-configuration)
    - [Deploy an Update](#deploy-an-update)
    - [Mender Configuration](#mender-configuration)
    - [Tear Down Server](#tear-down-server)
- [Advanced Configuration](#advanced-configuration)
  - [Custom Variables in bootstrap.sh](#custom-variables-in-bootstrapsh)
  - [Build Configuration Variables](#build-configuration-variables)
- [Architecture Notes](#architecture-notes)
- [License](#license)

## Quick Start

### Prerequisites

- Docker installed and running
- Git
- At least 100GB of free disk space
- Reliable internet connection
- The user under which the image is built must be added to `docker` group

```bash
$ sudo usermod -aG docker $USER
```

### Directory Structure Requirements

**Important**:
The meta layer repository must be located within the working directory where you run the bootstrap script. The bootstrap creates a Docker container that mounts the working directory, so the meta-layer must be accessible within that mount.

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
   git checkout <branch>
   ```

The repository URL is:
`git@github.com:wendylabsinc/meta-wendyos-jetson.git`

2. **Run the bootstrap script**:

   Switch back to working folder and run the `bootstrap` script:

   ```bash
   cd /path/to/project
   ./meta-wendyos/bootstrap.sh
   ```

   The bootstrap script will:
   - Validate that the meta-layer is within the working directory
   - Clone all required Yocto layers (`poky`, `meta-openembedded`, `meta-tegra`, etc.)
   - Create the `build` directory using the meta layer `conf/template` configuration templates
   - Set up the Docker build environment in `docker`
   - Build the Docker image (only if it does not already exist)

3. **Customize build configuration** (optional):

   Edit `build/conf/local.conf` to customize:
   - `DL_DIR` - Download directory for source tarballs (recommended for caching)
   - `SSTATE_DIR` - Shared state cache directory (speeds up rebuilds)
   - `MACHINE` - Target machine configuration:
     - `jetson-orin-nano-devkit-nvme-edgeos` (NVMe boot) [**default**]
     - `jetson-orin-nano-devkit-edgeos` (eMMC/SD card boot)
   - `EDGEOS_FLASH_IMAGE_SIZE` - Flash image size: "64GB"):
     - `"4GB"` - 3.2GB Mender storage (~1.3GB per rootfs partition)
     - `"8GB"` - 6.4GB Mender storage (~2.9GB per rootfs partition)
     - `"16GB"` - 12.8GB Mender storage (~6GB per rootfs partition)
     - `"32GB"` - 25.7GB Mender storage (~12GB per rootfs partition)
     - `"64GB"` - 51GB Mender storage (~25GB per rootfs partition) [**default**]

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

   Depending on the hardware configuration, the build process can take several hours on the first run (when the `download` and `sstate-cache` folders are empty!).

### Flash the SD Card or NVMe

The build produces a flash package at:
```
build/tmp/deploy/images/<machine>/edgeos-image-<machine>.rootfs.tegraflash.tar.gz
```

**Important**: The flashing script differs based on your target machine:
- **NVMe** (`jetson-orin-nano-devkit-nvme-edgeos`) → use `doexternal.sh`
- **eMMC/SD card** (`jetson-orin-nano-devkit-edgeos`) → use `dosdcard.sh`

#### For eMMC/SD Card Builds

**Option 1: Directly Flash to SD Card**

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/jetson-orin-nano-devkit-edgeos/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./dosdcard.sh /dev/sdX
```

Replace `/dev/sdX` with the actual SD card device (e.g., `/dev/sdb`).

**Warning**: This will erase all data on the device!

**Option 2: Create a Flashable .img File**

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/jetson-orin-nano-devkit-edgeos/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./dosdcard.sh wendyos.img
```

This creates `wendyos.img`, which you can flash using dd or GUI tools (see below).

#### For NVMe Builds

**Option 1: Directly Flash to NVMe**

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/jetson-orin-nano-devkit-nvme-edgeos/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./doexternal.sh /dev/nvme0n1
```

Replace `/dev/nvme0n1` with your actual NVMe device path.

**Warning**: This will erase all data on the device!

**Option 2: Create a Flashable .img File**

```bash
cd /path/to/project
mkdir ./deploy
tar -xzf ./build/tmp/deploy/images/jetson-orin-nano-devkit-nvme-edgeos/edgeos-image-*.tegraflash.tar.gz -C ./deploy
cd ./deploy
sudo ./doexternal.sh -s 64G wendyos-nvme.img
```

**Important**: You **must** specify the size with `-s` parameter, and it **must match** your `EDGEOS_FLASH_IMAGE_SIZE` setting in `build/conf/local.conf`:
- `-s 4G` for `EDGEOS_FLASH_IMAGE_SIZE = "4GB"`
- `-s 8G` for `EDGEOS_FLASH_IMAGE_SIZE = "8GB"`
- `-s 16G` for `EDGEOS_FLASH_IMAGE_SIZE = "16GB"`
- `-s 32G` for `EDGEOS_FLASH_IMAGE_SIZE = "32GB"`
- `-s 64G` for `EDGEOS_FLASH_IMAGE_SIZE = "64GB"`

**Warning**: Using a mismatched size will result in a corrupted or non-bootable image!

This creates `wendyos-nvme.img`, which you can flash using dd or GUI tools (see below).

#### Flashing the .img File

**Command line (works for both SD card and NVMe):**
```bash
# For SD card
sudo dd if=wendyos.img of=/dev/sdX bs=4M status=progress oflag=sync conv=fsync

# For NVMe
sudo dd if=wendyos-nvme.img of=/dev/nvme0n1 bs=4M status=progress oflag=sync conv=fsync

sync
```

**GUI tools:**
- balenaEtcher (recommended)
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
- `/dev/nvme0n1p15` - UDA partition (NVIDIA reserved, not used by EdgeOS)
- `/dev/nvme0n1p17` - Mender data partition (expandable, mounted at `/data`)

### Manual Update

For testing or offline updates, you can manually install a `.mender` artifact without a Mender server:

**1. Transfer the artifact to the device:**

```bash
scp edgeos-image-*.mender root@<device-ip>:/tmp/
```

**2. Install the update:**

```bash
ssh root@<device-ip>
sudo mender-update install /tmp/edgeos-image-*.mender
```

**3. Reboot to apply:**

```bash
sudo reboot
```

**4. Verify the update:**

After reboot, check the new version:

```bash
cat /etc/os-release | grep VERSION_ID
mender-update show-artifact
```

**5. Commit the update:**

If the system boots successfully and you're satisfied with the new version:

```bash
sudo mender-update commit
```

**Note:** If you don't commit, Mender will automatically roll back to the previous version on the next reboot.

### Mender Server Update

For production deployments, use the Mender server for centralized OTA update management.

#### Setting Up Mender Server

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

#### Device Configuration

The Mender client on the Jetson device is pre-configured to connect to `https://docker.mender.io`. Ensure the `/etc/hosts` entry is set (see step 3 above).

The server's TLS certificate is already included in the image at `/etc/mender/server.crt`.

#### Deploy an Update

1. Open https://docker.mender.io/ in your browser
2. Log in with `admin@docker.mender.io` / `password123`
3. Go to **Devices → Pending** and accept your Jetson device
4. Upload a `.mender` artifact under **Artifacts**
5. Create a deployment under **Deployments → Create deployment**
6. Monitor the update progress on the device

#### Mender Configuration

- **Server URL**: `https://docker.mender.io`
- **Update poll interval**: 30 minutes
- **Inventory poll interval**: 8 hours
- **Artifact naming**: `${IMAGE_BASENAME}-${MACHINE}-${IMAGE_VERSION_SUFFIX}`

#### Tear Down Server

```bash
# Stop and remove containers + volumes (wipes all data)
docker compose down -v

# Optional: Remove server files
cd <server_dir>/..
rm -rf mender-server
```

## Advanced Configuration

### Custom Variables in bootstrap.sh

You can modify these variables in `bootstrap.sh` before running:
- `IMAGE_NAME` - Base name for the OS (default: "wendyos")
- `USER_NAME` - Docker container username (default: "dev")
- `YOCTO_BRANCH` - Yocto release branch (default: "scarthgap")

### Build Configuration Variables

In `build/conf/local.conf`:
- `EDGEOS_FLASH_IMAGE_SIZE` - Flash image size: "4GB", "8GB", "16GB", "32GB", "64GB" (default: "8GB")
- `EDGEOS_DEBUG` - Enable debug packages (default: 0)
- `EDGEOS_DEBUG_UART` - Enable UART debug output (default: 0)
- `EDGEOS_USB_GADGET` - Enable USB gadget mode (default: 0)
- `EDGEOS_PERSIST_JOURNAL_LOGS` - Persist logs to storage (default: 0)

**Note**: Choose `EDGEOS_FLASH_IMAGE_SIZE` based on your target storage device capacity and expected rootfs size. Larger images provide more space for root filesystems and future updates.

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
