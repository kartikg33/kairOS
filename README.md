# kairOS
A Linux distribution for the agentic era.

## License

The source code, build configuration, build recipes, scripts, patches,
and other original files in this repository are licensed under the
Apache License, Version 2.0.

See [LICENSE](LICENSE).

Software included or referenced by the build system is subject to its
respective upstream copyright and license terms.

## Install Kairos

Kairos is distributed as bootable Ubuntu-based ISO images with Kairos tooling preinstalled.

### 1. Download a release

Download the ISO for your machine architecture from the project's GitHub Releases page.

- **amd64** — for most Intel and AMD PCs
- **arm64** — for compatible ARM64 hardware

Download the corresponding `.iso` file and its `.sha256` checksum file.

### 2. Verify the image

From the directory containing the downloaded files:

```bash
sha256sum -c kairos-*.iso.sha256
```

The verification should report `OK`.

### 3. Write the ISO to a USB drive

Use a disk-image writing tool such as GNOME Disks, Raspberry Pi Imager, or `dd`.

For example, on Linux:

```bash
sudo dd if=kairos-<version>-<arch>.iso of=/dev/<usb-device> bs=4M status=progress oflag=sync
```

Replace `/dev/<usb-device>` with the correct USB device.

Be careful: writing an ISO to the wrong device will overwrite it.

Alternatively, use a graphical disk-image writer if you prefer.

### 4. Boot

Insert the USB drive into the target machine and boot from it.

Follow the Ubuntu installer to install Kairos.


## Build Locally

The repository contains a single build script for creating Kairos images from the corresponding official Ubuntu release image.

### Requirements

A Linux machine with:

- `sudo` access
- internet access
- enough disk space for the source image and build workspace

The build script installs its own build dependencies.

### Build amd64

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>

chmod +x build.sh
sudo ./build.sh amd64
```

The resulting image is written to:

```bash
output/
```

### Build arm64

On an ARM64 Linux machine:

```bash
sudo ./build.sh arm64
```

### Build output

The build produces:

```bash
output/
├── kairos-<version>-amd64.iso
├── kairos-<version>-amd64.iso.sha256
```

or:

```bash
output/
├── kairos-<version>-arm64.iso
├── kairos-<version>-arm64.iso.sha256
```

The build uses the Ubuntu release configured by `build.sh` and adds the Kairos components defined by the build configuration.

For development, prefer changing the build configuration rather than maintaining separate manual build instructions.