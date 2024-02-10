source "./src/_vars.sh"
source "./src/_helpers.sh"

source "./src/_prompt.sh"
source "./src/main.sh"
source "./src/settings.sh"

set -e

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

# --------- Fist step --------- #
dashboard_prompt
# --------- Second step --------- #
print_color $GREEN "\n#------------------------------------------------------------------------------------------------#\n"
timezone_prompt
# --------- Third step --------- #
clear
print_color $GREEN "\n#------------------------------------------------------------------------------------------------#\n"
user_prompt
user_password_prompt
root_password_prompt
hostname_prompt
# --------- Fourth step --------- #
print_color $GREEN "\n#------------------------------------------------------------------------------------------------#\n"
swap_method_prompt
efi_partition_prompt
root_partition_prompt
if [[ "$SWAP_METHOD" == "1" ]];then
  swap_partition_prompt
  hibernation_prompt
else
  HIBERNATION="n"
fi

# --------- Fifth step --------- #
print_color $GREEN "\n#------------------------------------------------------------------------------------------------#\n"
bootloader_prompt
# --------- Summary step --------- #
print_summary

# ------------------------------------------------------------------------------------------ Main install ------------------------------------------------------------------------------------------ #
prep
setup_partition
locale_config
network
adduser
bootloader
install_config

setting_swap
setting_powerbutton
setting_reflector
if [[ -z "$(grep "plymouth" $MOUNT_POINT/etc/mkinitcpio.conf)" ]]; then
  plymouth
fi

arch-chroot $MOUNT_POINT mkinitcpio -P

genfstab -t UUID $MOUNT_POINT >> $MOUNT_POINT/etc/fstab

rm -rf $(pwd)
