
# DEBUG WITH GDB
#qemu-system-x86_64 -cpu qemu64 \
#  -drive if=pflash,format=raw,unit=0,file=./OVMF.fd,readonly=on \
#  -drive if=pflash,format=raw,unit=1,file=./OVMF.fd \
#  -net none -drive file=bootloader.img,format=raw,index=0,media=disk -S -s

# Check if the file is already in the current directory
if [ ! -f "./OVMF.fd" ]; then
    echo "Local OVMF.fd not found. Searching system..."
    
    # Dynamically search common paths for the firmware
    SYSTEM_OVMF=$(find /usr/share/ovmf /usr/share/OVMF /usr/share/qemu -name "OVMF.fd" 2>/dev/null | head -n 1)

    # Fallback: if find didn't grab it, try the standard Debian location manually
    if [ -z "$SYSTEM_OVMF" ]; then
        SYSTEM_OVMF="/usr/share/ovmf/OVMF.fd"
    fi

    # Safety check: Verify the system file actually exists before copying
    if [ ! -f "$SYSTEM_OVMF" ]; then
        echo "Error: OVMF.fd could not be found anywhere on the system."
        echo "Please make sure it is installed by running: sudo apt install ovmf"
        exit 1
    fi

    echo "Found system OVMF at: $SYSTEM_OVMF"
    echo "Copying OVMF.fd to current directory..."
    cp "$SYSTEM_OVMF" ./OVMF.fd
else
    echo "Local OVMF.fd already exists. Skipping copy."
fi

qemu-system-x86_64 -cpu qemu64 \
  -drive if=pflash,format=raw,unit=0,file=./OVMF.fd,readonly=on \
  -drive if=pflash,format=raw,unit=1,file=./OVMF.fd \
  -net none -drive file=bootloader.img,format=raw,index=0,media=disk
