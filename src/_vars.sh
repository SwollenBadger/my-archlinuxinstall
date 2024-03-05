# ---------------------- Vars and helpers script ---------------------- #
BLACK=30
RED=31
GREEN=32
YELLOW=33
BLUE=34
MAGENTA=35
CYAN=36
WHITE=37

# -- Detect cpu vendor
CPU_VENDOR=$(lscpu | grep "^Vendor ID" | awk '{print $3}')
BLUETOOTH_USB=$(lsusb | grep -i "bluetooth")
BLUETOOTH_PCI=$(lspci | grep -i "bluetooth")

#-- Mount Point
MOUNT_POINT="/mnt"
ESP_MOUNT_POINT="$MOUNT_POINT/boot"
