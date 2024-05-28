function prep() {
    echo -e

    if [[ ! -e /etc/pacman.d/mirrorlist.bak ]]; then
        print_color $MAGENTA "Setting pacman and reflector... \n"
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

        reflector --verbose\
            --score 12 \
            --age 12 \
            --protocol https\
            --sort rate \
            --save /etc/pacman.d/mirrorlist
    fi

    if [[ ! -e /etc/pacman.conf.bak ]]; then
        pacman-key --init && pacman-key --populate || true

        cp /etc/pacman.conf /etc/pacman.conf.bak

        sed -i '/^#ParallelDownloads = 5/s/^#//' /etc/pacman.conf
        sed -i.bak '/^#[[:space:]]*\[multilib\]/,/^#[[:space:]]*Include = \/etc\/pacman.d\/mirrorlist/s/^#//' /etc/pacman.conf

        pacman -Sy
    fi

    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    sleep 3
}

function setup_partition() {
    echo -e
    print_color $MAGENTA "Preparing your partition... \n"
    sleep 3

    umount -l $ESP_MOUNT_POINT 2>/dev/null || true
    umount -l $MOUNT_POINT/boot/efi 2>/dev/null || true
    umount -l $MOUNT_POINT -R 2>/dev/null || true

    delete_efi_entry "Linux Boot Manager"
    delete_efi_entry "Archlinux"

    if [ -z "$(blkid -s TYPE -o value $EFI_PARTITION | grep -E "v?fat$")" ];then
        yes | mkfs.fat -F32 -n EFI $EFI_PARTITION
    fi
    yes | mkfs.ext4 -L Archlinux $ROOT_PARTITION

    mount $ROOT_PARTITION $MOUNT_POINT
    mount $EFI_PARTITION $ESP_MOUNT_POINT --mkdir

    rm -rf $MOUNT_POINT/boot/{EFI/systemd,EFI/Archlinux,*.img,loader,vmlinuz-linux,grub} 2>/dev/null || true
    rm -rf $MOUNT_POINT/boot/efi/{EFI/systemd,EFI/Archlinux,*.img,loader,vmlinuz-linux,grub} 2>/dev/null || true
    rm -rf $ESP_MOUNT_POINT/{EFI/systemd,EFI/Archlinux,*.img,loader,vmlinuz-linux,grub} 2>/dev/null || true

    BASE_PACKAGE="base base-devel sudo linux linux-headers linux-firmware openssl"
    NETWORK_PACKAGE="networkmanager nm-connection-editor wpa_supplicant wireless_tools netctl openssh"
    REFLECTOR_PACKAGE="reflector pacman-contrib"
    PLYMOUTH_PACKAGE="plymouth"
    FS_PACKAGE="ntfs-3g exfatprogs"
    AUDIO_PACKAGE="pipewire pipewire-pulse pipewire-jack pipewire-alsa wireplumber"
    OTHER_PACKAGE="git vim zsh"

    if [[ -n "$BLUETOOTH_USB" ]] || [[ -n "$BLUETOOTH_PCI" ]]; then
        BLUETOOTH_PACAKGE="bluez bluez-utils blueman"
    fi

    if [[ $BOOTLOADER == "1" ]]; then
        BOOTLOADER_PACKAGE="grub os-prober efibootmgr dosfstools mtools"
    elif [[ $BOOTLOADER == "2" ]]; then
        BOOTLOADER_PACKAGE="efibootmgr dosfstools mtools"
    else
        error "Failed to get bootloader"
    fi

    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        MICROCODE_PACKAGE="intel-ucode"
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        MICROCODE_PACKAGE="amd-ucode"
    else
        print_color $YELLOW "Unknown cpu, no microcode installed\n"
        sleep 3
    fi

    if [[ "$SWAP_METHOD" == "2" ]]; then
        SWAP_PACKAGE="zram-generator"
    else
        SWAP_PACKAGE=""
    fi

    pacstrap $MOUNT_POINT \
        $BASE_PACKAGE \
        $BOOTLOADER_PACKAGE \
        $MICROCODE_PACKAGE \
        $SWAP_PACKAGE \
        $NETWORK_PACKAGE \
        $REFLECTOR_PACKAGE \
        $PLYMOUTH_PACKAGE \
        $FS_PACKAGE \
        $AUDIO_PACKAGE \
        $BLUETOOTH_PACAKGE \
        $OTHER_PACKAGE

    cp $MOUNT_POINT/etc/pacman.conf /etc/pacman.conf.bak
    sed -i '/^#ParallelDownloads = 5/s/^#//' $MOUNT_POINT/etc/pacman.conf
    sed -i.bak '/^#[[:space:]]*\[multilib\]/,/^#[[:space:]]*Include = \/etc\/pacman.d\/mirrorlist/s/^#//' $MOUNT_POINT/etc/pacman.conf

    print_color $GREEN "ROOT has been set \n"
    sleep 3
}

function locale_config() {
    echo -e
    print_color $MAGENTA "Setting locale and language...\n"

    ln -sf /usr/share/zoneinfo/$TIME_ZONE $MOUNT_POINT/etc/localtime
    timedatectl set-ntp true || true
    hwclock --systohc || true

    ADDITIONAL_LOCALE="id_ID.UTF-8"

    sed -i '/^#en_GB.UTF-8/s/^#//' $MOUNT_POINT/etc/locale.gen
    sed -i '/^#en_US.UTF-8/s/^#//' $MOUNT_POINT/etc/locale.gen
    sed -i "/^#$ADDITIONAL_LOCALE/s/^#//" $MOUNT_POINT/etc/locale.gen

    echo "LANG=en_GB.UTF-8" >> $MOUNT_POINT/etc/locale.conf
    echo "LANGUAGE=en_GB.UTF-8" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_TIME=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_ADDRESS=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_IDENTIFICATION=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_TELEPHONE=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_PAPER=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_MONETARY=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_NUMERIC=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf
    echo "LC_MEASUREMENT=$ADDITIONAL_LOCALE" >> $MOUNT_POINT/etc/locale.conf

    arch-chroot $MOUNT_POINT locale-gen

    print_color $GREEN "Successfully setting locale\n"
    sleep 3
}

function network() {
    echo -e
    print_color $MAGENTA "Setting network...\n"

    echo "$HOSTNAME" > $MOUNT_POINT/etc/hostname
    echo -e "127.0.0.1 localhost" > $MOUNT_POINT/etc/hosts
    echo -e "::1 localhost " >> $MOUNT_POINT/etc/hosts
    echo -e "127.0.0.1 $HOSTNAME" >> $MOUNT_POINT/etc/hosts

    arch-chroot $MOUNT_POINT systemctl enable NetworkManager sshd

    print_color $GREEN "Successfully setting network\n"
    sleep 3
}

function adduser() {
    echo -e
    print_color $MAGENTA "Adding user...\n"

    useradd -mG wheel -R $MOUNT_POINT $USERNAME || true
    arch-chroot /mnt usermod -p $(echo "$USER_PASSWORD" | openssl passwd -1 -stdin) $USERNAME

    if [[ -n "$ROOT_PASSWD" ]]; then
        arch-chroot /mnt usermod -p $(echo "$ROOT_PASSWORD" | openssl passwd -1 -stdin) root
    fi

    sed -E -i 's/^# (%wheel ALL=\(ALL:ALL\) ALL)/\1/' $MOUNT_POINT/etc/sudoers || true

    print_color $GREEN "Successfully adding user\n"
    sleep 3
}

function grub() {
    echo -e
    print_color $MAGENTA "Installing grub...\n"

    ROOT_ID=$(blkid -s UUID -o value $ROOT_PARTITION)

    grub-install --target=x86_64-efi --efi-directory=$ESP_MOUNT_POINT --boot-directory=$MOUNT_POINT/boot --bootloader-id=Archlinux

    EXISTING_OPTIONS=$(grep "GRUB_CMDLINE_LINUX_DEFAULT" $MOUNT_POINT/etc/default/grub | grep -oP '(?<=\")[^\"]+(?=\")')
    NEW_OPTIONS="GRUB_CMDLINE_LINUX_DEFAULT=\"$EXISTING_OPTIONS splash\""
    sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=5/' $MOUNT_POINT/etc/default/grub
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=/GRUB_DISABLE_OS_PROBER=/' $MOUNT_POINT/etc/default/grub
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW_OPTIONS}|" $MOUNT_POINT/etc/default/grub

    echo -e "menuentry \"Shutdown\" {" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "	echo \"System shutting down...\"" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "	halt" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "}" >> $MOUNT_POINT/etc/grub.d/40_custom

    echo -e "menuentry \"Restart\" {" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "	echo \"System restarting...\"" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "	reboot" >> $MOUNT_POINT/etc/grub.d/40_custom
    echo -e "}" >> $MOUNT_POINT/etc/grub.d/40_custom

    # Add efistub for my hackintosh OpenLinuxBoot.efi
    mkdir -p $MOUNT_POINT/boot/loader/entries/
    echo "title   Archlinux" > "$MOUNT_POINT/boot/loader/entries/archlinux.conf"
    echo "linux   /vmlinuz-linux" >> "$MOUNT_POINT/boot/loader/entries/archlinux.conf"
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        echo "initrd  /intel-ucode.img" >> "$MOUNT_POINT/boot/loader/entries/archlinux.conf"
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        echo "initrd  /amd-ucode.img" >> "$MOUNT_POINT/boot/loader/entries/archlinux.conf"
    else
        print_color $YELLOW "Unknown cpu, no microcode installed\n"
    fi
    echo "initrd  /initramfs-linux.img" >> "$MOUNT_POINT/boot/loader/entries/archlinux.conf"
    echo "options root=UUID=$ROOT_ID rw log_level=3 quiet splash" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"

    print_color $GREEN "Grub installed successfully.\n"
    sleep 3
}

function systemd() {
    echo -e
    ESP_MOUNT_POINT="$MOUNT_POINT/boot" # Override esp mount point

    print_color $MAGENTA "Installing systemd boot...\n"

    mkdir -p $MOUNT_POINT/etc/pacman.d/hooks 2>/dev/null

    if [ ! -d "$ESP_MOUNT_POINT" ]; then
        echo "EFI System Partition (ESP) not found at $ESP_MOUNT_POINT. Adjust the mount point."
        exit 1
    fi

    bootctl --esp-path=$ESP_MOUNT_POINT install || true

    echo "default archlinux*" > "$ESP_MOUNT_POINT/loader/loader.conf"
    echo "timeout 5" >> "$ESP_MOUNT_POINT/loader/loader.conf"
    echo "console-mode max" >> "$ESP_MOUNT_POINT/loader/loader.conf"

    ROOT_ID=$(blkid -s UUID -o value $ROOT_PARTITION)

    echo "title   Archlinux" > "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"
    echo "linux   /vmlinuz-linux" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"
    if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        echo "initrd  /intel-ucode.img" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"
    elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        echo "initrd  /amd-ucode.img" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"
    else
        print_color $YELLOW "Unknown cpu, no microcode installed\n"
    fi
    echo "initrd  /initramfs-linux.img" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"
    echo "options root=UUID=$ROOT_ID rw log_level=3 quiet splash" >> "$ESP_MOUNT_POINT/loader/entries/archlinux.conf"

    echo "[Trigger]" > $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "Type = Package" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "Operation = Upgrade" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "Target = systemd" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook

    echo -e "\n" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook

    echo "[Action]" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "Description = Gracefully upgrading systemd-boot..." >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "When = PostTransaction" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook
    echo "Exec = /usr/bin/systemctl restart systemd-boot-update.service" >> $MOUNT_POINT/etc/pacman.d/hooks/95-systemd-boot.hook

    rm -rf $ESP_MOUNT_POINT/EFI/Linux
    print_color $GREEN "Systemd-boot installed successfully.\n"
    sleep 3
}

function bootloader() {
    if [[ $BOOTLOADER == "1" ]];then
        grub
    elif [[ $BOOTLOADER == "2" ]]; then
        systemd
    else
        print_color $RED "INVALID bootloader choice\n"
        print_color $RED "Bootloader not installed, you won't be able to boot to your Operating System\n"
        sleep 3
    fi
}

