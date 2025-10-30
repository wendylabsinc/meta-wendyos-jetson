
# EdgeOS for NVIDIA Jetson Nano Developer Kit

This repository provides the meta-layer and build flow to build **EdgeOS** for the **NVIDIA Jetson Nano Developer Kit**.

## Quick Start

### Steps to build NVIDIA Jetson Nano Dev Kit

1. Download the `bootstrap.sh` script into an empty folder.
2. Setup the build environment (the `meta-edgeos` repo branch must be provided through the `EDGEOS_BRANCH` variable).

```bash
$ EDGEOS_BRANCH=<branch> ./bootstrap.sh
```

3. Customize the `build/conf/local.conf` file, particularly:
   **DL_DIR**
   **SSTATE_DIR**

Follow the instructions displayed by the bootstrap script to build the Linux image.

**Notes**
- Currently, only SD card image generation is supported.
- The bootstrap script initializes the Yocto environment, sets up layers, and prints the exact building command to be used.
- Make sure you have a reliable internet connection and plenty of disk space before starting a build.

### Flash the SD card

There ar two ways to flash an SD card, both using the same `dosdcard.sh` shell script:
- directly flash the SD card
- prepare an `.img` file

#### Directly flash the SD card

Change directory to project root (where the `repos`, `layers` and `build` folder are located).

The image to be flashed: `edgeos-image-jetson-orin-nano-devkit.rootfs.tegraflash.tar.gz` (or something similar)
The SD card device: `/dev/sdX`

That `.tar.gz` contains the root filesystem, bootloader binaries, kernel, DTBs, etc.
`dosdcard.sh` is a helper script provided by meta-tegra that allows flashing the image.

```bash
$ cd <root folder>
$ mkdir ./deploy
$ tar -xzf ./build/images/jetson-orin-nano-devkit/<image> -C ./deploy
$ cd ./deploy
$ sudo ./dosdcard.sh /dev/sdX
```

#### Generate the image

The same `dosdcard.sh` script can be used to assembles all the above mentioned components into a single flash-able disk image (.img) suitable for writing to an SD card.

```bash
$ cd <root folder>
$ mkdir ./deploy
$ tar -xzf ./build/images/jetson-orin-nano-devkit/<image> -C ./deploy
$ cd ./deploy
$ sudo ./dosdcard.sh [<image_name>]
```

This generates an `.img` file, which can then be flashed like any other image:

```bash
$ sudo dd if=<image_name>.img of=/dev/sdX bs=4M status=progress conv=fsync
$ sync
```

Replace `/dev/sdX` with your actual device (e.g., `/dev/sda`).

For a GUI flash method:
- `balenaEtcher`, `Raspberry Pi Imager`, or `GNOME Disks` all should be fine.
- Just select `<image_name>.img` as the source, and the SD card as the target.

### Test the Mender update

#### Mender Server

Installation of the required dependencies:

```bash
$ sudo apt install docker
$ sudo apt install docker.io docker-plugin git
$ sudo systemctl enable --now docker
```

Installation of the `Mender Demo Server` (at the time of writing, tag `v4.0.1` is the latest):

```bash
$ cd <server_dir>
$ git clone https://github.com/mendersoftware/mender-server
$ cd mender-server
$ git checkout v4.0.1
```

 If the server is on LAN IP <ip>, use that IP on BOTH the server and device(s):

 ```bash
 $ echo '<ip> docker.mender.io s3.docker.mender.io' | sudo tee -a /etc/hosts
 ```

Also, it might be that the `443/tcp` port has to be open.
Bring up the Mender Server container:

```bash
$ docker compose up -d

# crete the user (only at the first run)
$ docker compose exec useradm useradm create-user --username "admin@docker.mender.io" --password "password123"
```

Quick sanity checks (on server):

```bash
$ docker compose ps
$ docker compose logs -f api-gateway deployments deviceauth
```

Tear down the server:

```bash
# stop and remove containers + volumes (wipes data)
$ docker compose down -v

# and if you cloned for a temporary try:
$ cd <server_dir>/..
$ rm -rf mender-server

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
