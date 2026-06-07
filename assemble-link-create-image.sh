# See https://web.archive.org/web/20190706212328/https://gist.github.com/AdrianKoshka/5b6f8b6803092d8b108cda2f8034539a
# for creating a UEFI USB properly, then move bootx64.efi to /efi/usb on the first USB partition

# This probably works for qemu though, our bootloader (BOOTX64.EFI) is a PE executable in a FAT image ! lmao
echo "building bootload.img from bootloader.nasm"

# assemble for qemu
nasm -f win64 bootloader.nasm -o bootloader.obj
# link with PE header (DOS header + COFF header + "optional" PE header) to create PE executable
# my code starts at offset 0x200 in BOOTX64.EFI, and the program is filled with 0xCC till 1024 bytes for some reason
clang --target=x86_64-unknown-windows -nostdlib -Wl,-entry:start -Wl,-subsystem:efi_application -fuse-ld=lld -o BOOTX64.EFI bootloader.obj
# create vfat image to copy PE executable into
dd if=/dev/zero of=bootloader.img bs=1M count=1
sudo mkfs.vfat bootloader.img
# create EFI MSDOS directory in FAT image
mmd -i bootloader.img ::EFI
# create EFI/BOOT directory in FAT image
mmd -i bootloader.img ::EFI/BOOT
# copy PE executable to FAT image
mcopy -i bootloader.img BOOTX64.EFI ::EFI/BOOT/BOOTX64.EFI

echo "Done... Created bootloader.img"

read -n 1 -r -p "To build USB press y else n: " response
echo ""

# If they press anything other than 'y', kill the script right here
if [[ "${response,,}" != "y" ]]; then
    echo "Exiting."
    exit 0
fi

# put on USB
lsblk
read -n 1 -s -r -p "Press any key to continue if UEFI USB is plugged in with efi/boot folder"
echo ""
doas mount /dev/sda1 /mnt
cp BOOTX64.EFI bootx64.efi
doas rm -r /mnt/efi/boot/bootx64.efi
sync && sync
doas cp bootx64.efi /mnt/efi/boot/bootx64.efi
sync && sync
doas umount /mnt
sync && sync
echo "Done, can restart and test USB if want"
