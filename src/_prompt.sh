function dashboard_prompt() {
    clear
    echo -en "\e[33m
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░

  This script was intended to automate my archlinux installation process

  This script suposed to run inside arch-chroot
  make sure you have complete all step down below:

  1. Create a partition (important), this script doesn't have support for btrfs (only support for ext partition) partition
  2. Configure your mirrors (optional)
  3. Make sure your partition is 500M or 1G
  4. Proceed with caution, if screwed up i suggest to start over from beginning

    \e[0m"

    print_color $CYAN "Proceed to install (Yes/No): "
    read -n1 -r INSTALL_CONFIRM

    if [[ "$INSTALL_CONFIRM" =~ [Nn] ]];then
        clear
        print_color $GREEN "Good bye\n"
        exit 0
    fi
}

function timezone_prompt() {
    # -- Select timezone
    TIME_ZONE=$(tzselect)
    echo -e
}

function user_prompt() {
    # -- Create username
    print_color $CYAN "=> Enter your username: "
    read USERNAME
    if [[ -z "$USERNAME" ]]; then
        error "This option cannot be empty, run script again\n"
        exit 0
    fi
}

function user_password_prompt() {
    # -- Set user password
    print_color $CYAN "=> Enter your username password (It will visible throughout install, be careful): "
    read USER_PASSWORD
    if [[ -z "$USER_PASSWORD" ]]; then
        error "This option cannot be empty, run script again\n"
        exit 0
    fi
}

function root_password_prompt() {
    # -- Set root password
    print_color $CYAN "=> Enter your root password (It will visible throughout install, be careful): "
    read ROOT_PASSWORD
}

function hostname_prompt() {
    # -- Set hostname
    print_color $CYAN "=> Enter your hostname: "
    read HOSTNAME
    if [[ -z "$HOSTNAME" ]]; then
        error "This option cannot be empty, run script again\n"
        exit 0
    fi
}

function efi_partition_prompt() {
    # -- Select EFI partition
    echo -e
    lsblk -o name,start,size,type,fstype
    print_color $CYAN "=> Pick your efi partition, (/dev/xxx): "
    read EFI_PARTITION

    if [[ -z "$EFI_PARTITION" ]]; then
        error "This option cannot be empty, run script again\n"
        exit 0
    fi

    if [[ -z "$(blkid $EFI_PARTITION)" ]];then
        error "EFI partition doesn't exist, create the partition and run the script again\n"
        exit 0
    fi

    if [ -n "$(blkid -s TYPE -o value $EFI_PARTITION)" ]; then # -- There is multiple ridiculous code like this here, it's very amusing
        if [ -z "$(blkid -s TYPE -o value $EFI_PARTITION | grep -E "v?fat$")" ];then
            warn "$EFI_PARTITION have fstype of $(blkid -s TYPE -o value $EFI_PARTITION) will be FORMATED and ERASED for EFI partition\n"
            warn "If this is a mistake ABORT by pressing ctrl-c\n"
        fi
    fi
}

function root_partition_prompt() {
    # -- Set ROOT partition
    print_color $CYAN "=> Pick your root partition, all DATA wil be ERASED and FORMAT, (/dev/xxx): "
    read ROOT_PARTITION

    if [[ -z "$ROOT_PARTITION" ]]; then
        error "This option cannot be empty, run script again\n"
        exit 0
    fi

    if [ -z "$(blkid $ROOT_PARTITION)" ];then
        error "root partition doesn't exist, create the partition and run the script again\n"
        exit 0
    fi

    if [ -n "$(blkid -s TYPE -o value $ROOT_PARTITION)" ];then
        warn "$ROOT_PARTITION have fstype of $(blkid -s TYPE -o value $ROOT_PARTITION) will be FORMATED and ERASED for ROOT partition\n"
        warn "If this is a mistake ABORT by pressing ctrl-c\n"
    fi
}

function swap_method_prompt() {
    # -- Select The way swap
    print_color $WHITE "1) SWAP\n"
    print_color $WHITE "2) Zram\n"
    print_color $CYAN "=> Choose your swap method, pick other if you don't want to swap: "
    read -n1 -r SWAP_METHOD

    if [[ ! "$SWAP_METHOD" =~ [12] ]]; then
        echo -e
        warn "No swap configured\n"
        warn "Cannot setting hibernation\n"
    fi
}

function swap_partition_prompt() {
    print_color $CYAN "=> Enter your swap device either your swap partition (/dev/xxx) or swapfile (swapfile has to be /swapfile): "
    read SWAP_PARTITION

    if [[ -z "$SWAP_PARTITION" ]]; then
        print_color $RED "Option cannot be empty, run script again\n"
        exit 0
    fi

    if [ "$SWAP_PARTITION" != "/swapfile" ];then
        if [ -z "$(blkid $SWAP_PARTITION)" ];then
            print_color $RED "Swap partition doesn't exist make the swap partition first, then run the script again\n"
            exit 0
        fi
        if [ -n "$(blkid -s TYPE -o value $SWAP_PARTITION)" ] && [ "$(blkid -s TYPE $SWAP_PARTITION -o value| tr '[:upper:]' '[:lower:]')" != "swap" ] ;then
            warn "$EFI_PARTITION have fstype of $(blkid -s TYPE -o value $EFI_PARTITION) will be FORMATED and ERASED for EFI partition\n"
            warn "If this is a mistake ABORT by pressing ctrl-c\n"
        fi
    fi
}

function hibernation_prompt() {
    print_color $CYAN "=> Configure hibernation (yes/no) "
    read -n1 -r HIBERNATION

    if [[ -n "$HIBERNATION" ]]; then
        echo -e
    fi
}

function bootloader_prompt() {
    # -- Select Botloader
    print_color $WHITE "1) Grub\n"
    print_color $WHITE "2) Systemd-boot\n"
    print_color $CYAN "=> Choose your bootloader: "
    read -n1 -r BOOTLOADER

    if [[ -z "$BOOTLOADER" ]]; then
        print_color $RED "This option cannot be empty, run script again\n"
        exit 0
    fi

    if ! [[ "$BOOTLOADER" =~ [12] ]]; then
        print_color $RED "\nChoice INVALID"
        exit 0
    fi
}

function print_summary() {
    clear
    echo -e
    print_color $GREEN "Timezone: "
    echo -e "$TIME_ZONE"

    print_color $GREEN "Username: "
    echo -e "$USERNAME"

    print_color $GREEN "Password: "
    echo -e "$USER_PASSWORD"

    print_color $GREEN "Root password: "
    echo -e "$ROOT_PASSWORD"

    print_color $GREEN "Hostname: "
    echo -e "$HOSTNAME"

    print_color $GREEN "EFI partition: "
    echo -e "$EFI_PARTITION"

    print_color $GREEN "ROOT partition: "
    echo -e "$ROOT_PARTITION"

    print_color $GREEN "Swap: "
    if [[ "$SWAP_METHOD" == "1" ]]; then
        echo "Swap"
        print_color $GREEN "Swap partition: "
        echo -e "$SWAP_PARTITION"
    elif [[ "$SWAP_METHOD" == "2" ]]; then
        echo "ZRAM"
    else
        echo -e "No"
    fi

    print_color $GREEN "Hibernation: "
    if [[ "$HIBERNATION" =~ [Nn] ]]; then
        echo -e "No"
    else
        echo -e "Yes"
    fi

    print_color $GREEN "Bootloader: "
    if [[ "$BOOTLOADER" == "1" ]]; then
        echo "Grub"
    elif [[ "$BOOTLOADER" == "2" ]]; then
        echo "Systemd-boot"
    else
        echo -e "Failed to get bootloader"
    fi

    print_color $CYAN "=> Please check your configuration before continue\n"
    print_color $CYAN "   Continue ? "
    read -n1 -r CONTINUE

    if [[ "$CONTINUE" =~ [Nn] ]]; then
        echo -e
        exit 0
    fi
}
