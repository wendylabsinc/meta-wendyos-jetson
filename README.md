
# EdgeOS for NVIDIA Jetson Nano Developer Kit

This repository provides the meta-layer and build flow to build **EdgeOS** for the **NVIDIA Jetson Nano Developer Kit**.

## Quick Start

### Steps to build NVIDIA Jetson Nano Dev Kit

1. Clone the edgeOS meta layer (preferably in an empty folder)
```bash
$ git clone git@github.com:mihai-chiorean/meta-edgeos-jetson.git meta-edgeos
```

2. Setup the build environment
```bash
$ ./meta-edgeos/bootstrap.sh
```

Follow the instructions showed by the bootstrap script to build the image.

**Notes**
- The bootstrap script initializes the Yocto environment, sets up layers, and prints the exact building command to be used.
- Ensure you have a reliable internet connection and plenty of disk space before starting a build.

### Flash the SD card

Change directory to project root (where the `repos`, `layers` and `build` folder are located).

The image to be flashed: `edgeos-image-jetson-orin-nano-devkit.rootfs.tegraflash.tar.gz` (or something similar)
The SD card device: `/dev/sdX`

```bash
$ cd <root folder>
$ mkdir ./deploy
$ tar -xzf ./build/images/jetson-orin-nano-devkit/<image> -C ./deploy
$ cd ./deploy
$ sudo ./dosdcard.sh /dev/sdX
```
