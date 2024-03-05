function print_color() {
    color_code="$1"
    text="$2"
    echo -en "\e[${color_code}m${text}\e[0m"
}

# Function to check for the existence of a swap partition
function check_swap_partition() {
    local swap_partitions
    swap_partitions=$(arch-chroot $MOUNT_POINT awk '/\s+partition\s+/{print $1}' /proc/swaps)
    if [ -n "$swap_partitions" ]; then
        return 0  # Found a swap partition
    else
        return 1  # No swap partition found
    fi
}

# Function to check for the existence of a swap file
function check_swap_file() {
    local swap_files
    swap_files=$(arch-chroot $MOUNT_POINT awk '/\s+file\s+/{print $1}' /proc/swaps)
    if [ -n "$swap_files" ]; then
        return 0  # Found a swap file
    else
        return 1  # No swap file found
    fi
}

function info() {
    local info_text=$1

    print_color $BLUE "Info: "
    print_color $WHITE "$info_text"
}

function warn() {
    warn_text=$1

    print_color $YELLOW "Warning: "
    print_color $WHITE "$warn_text"
}

function error() {
    local error_text=$1

    print_color $RED "Error: "
    print_color $WHITE "$error_text"
}

function delete_efi_entry() {
    label="$1"
    entry_numbers=()

    while IFS= read -r entry_number; do
        entry_number="${entry_number/\*}"
        entry_number="${entry_number#Boot}"
        entry_numbers+=("$entry_number")
    done < <(efibootmgr | grep -i "$label" | awk '{print $1}')

    if [ ${#entry_numbers[@]} -gt 0 ]; then
        for entry_number in "${entry_numbers[@]}"; do
            efibootmgr -b "$entry_number" -B
        done

        echo "EFI boot entry(s) with label '$label' deleted successfully"
    fi
}
