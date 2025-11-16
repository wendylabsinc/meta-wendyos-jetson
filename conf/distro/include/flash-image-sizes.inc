
# Flash Image Size Configurations for EdgeOS
#
# This file defines custom partition sizes for NVMe flash images.
# The image size is controlled by TEGRA_EXTERNAL_DEVICE_SECTORS,
# and APP partition sizes are controlled by ROOTFSPART_SIZE_DEFAULT.
#
# Usage: Set EDGEOS_FLASH_IMAGE_SIZE in local.conf or distro config
#        Values: "4GB", "8GB", "16GB", "32GB", "64GB" (default: "8GB")

EDGEOS_FLASH_IMAGE_SIZE ??= "8GB"

# Total sectors for different image sizes (sector size = 512 bytes)
# Formula: (SIZE_IN_GB * 1000 * 1000 * 1000) / 512
TEGRA_EXTERNAL_DEVICE_SECTORS:4GB = "7812500"
TEGRA_EXTERNAL_DEVICE_SECTORS:8GB = "15625000"
TEGRA_EXTERNAL_DEVICE_SECTORS:16GB = "31250000"
TEGRA_EXTERNAL_DEVICE_SECTORS:32GB = "62500000"
TEGRA_EXTERNAL_DEVICE_SECTORS:64GB = "125000000"

# Override based on EDGEOS_FLASH_IMAGE_SIZE
TEGRA_EXTERNAL_DEVICE_SECTORS = "${TEGRA_EXTERNAL_DEVICE_SECTORS:${EDGEOS_FLASH_IMAGE_SIZE}}"

# APP partition sizes (bytes) for different image sizes
# These values account for:
# - Fixed partitions (boot, recovery, esp, UDA, reserved): ~1.5GB
# - 100MB safety buffer for GPT overhead
# - Remaining space split between APP and APP_b partitions
#
# Formula per APP partition: ((total_bytes - fixed_bytes - buffer) / 2)

# Mender storage size in MB for different image sizes
# Mender uses this to calculate APP partition sizes automatically
# Note: These values are adjusted to account for Tegra fixed partitions (~1.5GB)
# and include safety margin for GPT overhead
#
# Formula: (total_size_gb - tegra_fixed_partitions_gb - safety_margin_gb) * 1000
#   4GB:  (4.0 - 0.7 - 0.1) * 1000 = 3200 MB
#   8GB:  (8.0 - 1.5 - 0.1) * 1000 = 6400 MB
#  16GB: (16.0 - 3.1 - 0.1) * 1000 = 12800 MB
#  32GB: (32.0 - 6.2 - 0.1) * 1000 = 25700 MB
#  64GB: (64.0 - 12.5 - 0.5) * 1000 = 51000 MB
MENDER_STORAGE_TOTAL_SIZE_MB = "${@{'4GB': '3200', '8GB': '6400', '16GB': '12800', '32GB': '25700', '64GB': '51000'}.get(d.getVar('EDGEOS_FLASH_IMAGE_SIZE'), '6400')}"
