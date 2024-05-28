function setting_hibernation_grub() {
    echo -e
    print_color $MAGENTA "Setting hibernation...\n"

    if [[ -z "$(grep "resume" $MOUNT_POINT/etc/default/grub)" ]]; then
        EXISTING_OPTIONS=$(grep "GRUB_CMDLINE_LINUX_DEFAULT" $MOUNT_POINT/etc/default/grub | grep -oP '(?<=\")[^\"]+(?=\")')

        # For my hackintosh OpenLinuxBoot
        EXISTING_STUB_OPTIONS=$(grep "options" $MOUNT_POINT/boot/loader/entries/archlinux.conf | sed 's/^options //')

        if [[ $SWAP_PARTITION == "/swapfile" ]]; then
            HIBERNATION_UUID=$(blkid -s UUID -o value $ROOT_PARTITION)
            RES_OFFSET=$(arch-chroot $MOUNT_POINT filefrag -v /swapfile | awk 'NR==4 {gsub(/[^0-9]/, "", $4); print $4}')

            NEW_OPTIONS="GRUB_CMDLINE_LINUX_DEFAULT=\"$EXISTING_OPTIONS resume=UUID=$HIBERNATION_UUID resume_offset=$RES_OFFSET\""
            # For my hackintosh OpenLinuxBoot
            NEW_OPTIONS_STUB="options $EXISTING_STUB_OPTIONS resume=UUID=$HIBERNATION_UUID resume_offset=$RES_OFFSET"
        else
            HIBERNATION_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)

            NEW_OPTIONS="GRUB_CMDLINE_LINUX_DEFAULT=\"$EXISTING_OPTIONS resume=UUID=$HIBERNATION_UUID\""
            # For my hackintosh OpenLinuxBoot
            NEW_OPTIONS_STUB="options $EXISTING_STUB_OPTIONS resume=UUID=$HIBERNATION_UUID"
        fi

        if [ -z "$HIBERNATION_UUID" ]; then
            print_color $YELLOW "Failed to obtain UUID. Exiting."
            exit 1
        fi

        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW_OPTIONS}|" $MOUNT_POINT/etc/default/grub
        # For my hackintosh OpenLinuxBoot
        sed -i "s|^options.*|${NEW_OPTIONS_STUB}|" $MOUNT_POINT/boot/loader/entries/archlinux.conf

        sed -i '/^HOOKS=/s/udev/udev resume/' $MOUNT_POINT/etc/mkinitcpio.conf

        print_color $GREEN "Successfully settings hibernation\n"
    else
        print_color $YELLOW "Hibernation already enabled\n"
    fi
    sleep 3
}

function setting_hibernation_systemd() {
    echo -e
    ESP_MOUNT_POINT="$MOUNT_POINT/boot" # Override esp mount point

    print_color $MAGENTA "Setting hibernation...\n"

    if [[ -z "$(grep "resume" $ESP_MOUNT_POINT/loader/entries/archlinux.conf)" ]]; then
        EXISTING_OPTIONS=$(grep "options" $ESP_MOUNT_POINT/loader/entries/archlinux.conf | sed 's/^options //')

        if [[ $SWAP_PARTITION == "/swapfile" ]]; then
            HIBERNATION_UUID=$(blkid -s UUID -o value $ROOT_PARTITION)
            RES_OFFSET=$(arch-chroot $MOUNT_POINT filefrag -v /swapfile | awk 'NR==4 {gsub(/[^0-9]/, "", $4); print $4}')

            NEW_OPTIONS="options $EXISTING_OPTIONS resume=UUID=$HIBERNATION_UUID resume_offset=$RES_OFFSET"
        else
            HIBERNATION_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)
            NEW_OPTIONS="options $EXISTING_OPTIONS resume=UUID=$HIBERNATION_UUID"
        fi

        if [ -z "$HIBERNATION_UUID" ]; then
            print_color $YELLOW "Failed to obtain UUID for hibernation. Exiting."
            exit 1
        fi

        sed -i "s|^options.*|${NEW_OPTIONS}|" $ESP_MOUNT_POINT/loader/entries/archlinux.conf
        sed -i "/^HOOKS=/s/udev/udev resume/" $MOUNT_POINT/etc/mkinitcpio.conf

        print_color $GREEN "Successfully settings hibernation\n"
    else
        print_color $YELLOW "Hibernation already enabled\n"
        exit 0
    fi
}

function zram() {
    echo -e
    print_color $MAGENTA "Setting zram with zram generator...\n"

    echo "[zram0]" > $MOUNT_POINT/etc/systemd/zram-generator.conf
    echo "compression-algorithm = zstd" >> $MOUNT_POINT/etc/systemd/zram-generator.conf
    echo "swap-priority=100" >> $MOUNT_POINT/etc/systemd/zram-generator.conf
    echo "nfs-type = swap" >> $MOUNT_POINT/etc/systemd/zram-generator.conf

    arch-chroot $MOUNT_POINT systemctl daemon-reload
    arch-chroot $MOUNT_POINT systemctl start /dev/zram0

    print_color $GREEN "Check zram with zramctl or swapon after reboot\n"
    sleep 3
}

function swap() {
    echo -e
    print_color $MAGENTA "Setting Swap...\n"

    # Check for swap partition
    check_swap_partition
    result_partition=$?

    # Check for swap file
    check_swap_file
    result_file=$?

    if [ "$result_partition" -eq 0 ] || [ "$result_file" -eq 0 ]; then
        print_color $YELLOW "Swap file or partition already exists.\n"

        if [[ ! "$HIBERNATION" =~ [Nn] ]]; then
            if [[ -d "$MOUNT_POINT/boot/grub" ]]; then
                setting_hibernation_grub || true
            else
                setting_hibernation_systemd || true
            fi
        fi

        exit 0
    fi

    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    SWAP_SIZE_DEFAULT=8192
    SWAP_SIZE_HALF=$((TOTAL_RAM / 2))
    SWAP_SIZE=$SWAP_SIZE_DEFAULT

    if [[ $SWAP_PARTITION == "/swapfile" ]]; then
        if [[ ! "$HIBERNATION" =~ [Nn] ]]; then
            SWAP_SIZE=$TOTAL_RAM
        else
            if [ $SWAP_SIZE_HALF -lt $SWAP_SIZE_DEFAULT ]; then
                SWAP_SIZE=$SWAP_SIZE_HALF
            fi
        fi

        arch-chroot $MOUNT_POINT dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
        arch-chroot $MOUNT_POINT chmod 600 $SWAP_PARTITION
    fi

    arch-chroot $MOUNT_POINT mkswap $SWAP_PARTITION -f
    arch-chroot $MOUNT_POINT swapon $SWAP_PARTITION

    print_color $GREEN "Swap succesfully created\n"

    if [[ ! "$HIBERNATION" =~ [Nn] ]]; then
        if [[ -d "$MOUNT_POINT/boot/grub" ]]; then
            setting_hibernation_grub || true
        else
            setting_hibernation_systemd || true
        fi
    fi
}

function setting_swap() {
    echo -e
    if [[ $SWAP_METHOD == "1" ]]; then
        swap || true
    elif [[ $SWAP_METHOD == "2" ]]; then
        zram
    else
        warn "INVALID SWAP choice, no swap configured\n"
        warn "Cannot setting hibernation\n"
    fi
}

function setting_powerbutton() {
    echo -e
    POWERHANDLETEXT="HandlePowerKey=ignore"
    POWERHANDLE=$(sudo grep -c $POWERHANDLETEXT $MOUNT_POINT/etc/systemd/logind.conf || true)

    if [[ $POWERHANDLE < 1 ]]; then
        print_color $MAGENTA "\nSetting up power button handling...\n"
        sleep 3

        sudo sed -i 's/^#\(HandlePowerKey=\)poweroff/\1ignore/' $MOUNT_POINT/etc/systemd/logind.conf

        print_color $GREEN "Powerkey ignored\n"
    else
        print_color $GREEN "Powerkey has been ignored\n"
    fi

    sleep 3
}

function setting_reflector() {
    echo -e
    print_color $MAGENTA "Setting reflector...\n"

    echo "--score 12" > $MOUNT_POINT/etc/xdg/reflector/reflector.conf
    echo "--age 12" >> $MOUNT_POINT/etc/xdg/reflector/reflector.conf
    echo "--protocol https" >> $MOUNT_POINT/etc/xdg/reflector/reflector.conf
    echo "--sort rate" >> $MOUNT_POINT/etc/xdg/reflector/reflector.conf
    echo "--save /etc/pacman.d/mirrorlist" >> $MOUNT_POINT/etc/xdg/reflector/reflector.conf

    arch-chroot $MOUNT_POINT systemctl enable reflector.timer

    print_color $GREEN "Reflector has been set \n"
    sleep 3
}

function plymouth() {
    echo -e
    print_color $MAGENTA "Setting plymouth...\n"

    hooks_line=$(grep '^HOOKS=' $MOUNT_POINT/etc/mkinitcpio.conf)
    new_hooks_line=$(echo "$hooks_line" | sed 's/\budev\b/udev plymouth/')

    sed -i "s|^HOOKS=.*$|$new_hooks_line|" $MOUNT_POINT/etc/mkinitcpio.conf

    echo -e "[Daemon]\n" > $MOUNT_POINT/etc/plymouth/plymouthd.conf
    echo -e "Theme=bgrt" >> $MOUNT_POINT/etc/plymouth/plymouthd.conf

    print_color $GREEN "Plymouth has been set\n"
    sleep 3
}
