# our bootloader (BOOTX64.EFI) is a PE executable in a FAT image ! lmao

# assemble
nasm -f win64 bootloader.asm -o bootloader.obj
# link with PE header to create PE executable
clang --target=x86_64-unknown-windows -nostdlib -Wl,-entry:start -Wl,-subsystem:efi_application -fuse-ld=lld -o BOOTX64.EFI bootloader.obj
# create vfat image to copy PE executable into
dd if=/dev/zero of=bootloader.img bs=1M count=1
mkfs.vfat bootloader.img
# create EFI MSDOS directory in FAT image
mmd -i bootloader.img ::EFI
# create EFI/BOOT directory in FAT image
mmd -i bootloader.img ::EFI/BOOT
# copy PE executable to FAT image
mcopy -i bootloader.img BOOTX64.EFI ::EFI/BOOT/BOOTX64.EFI

