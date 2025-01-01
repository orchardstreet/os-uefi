#! /bin/ash

# DEBUG WITH GDB
#qemu-system-x86_64 -cpu qemu64 \
#  -drive if=pflash,format=raw,unit=0,file=./OVMF.fd,readonly=on \
#  -drive if=pflash,format=raw,unit=1,file=./OVMF.fd \
#  -net none -drive file=bootloader.img,format=raw,index=0,media=disk -S -s
qemu-system-x86_64 -cpu qemu64 \
  -drive if=pflash,format=raw,unit=0,file=./OVMF.fd,readonly=on \
  -drive if=pflash,format=raw,unit=1,file=./OVMF.fd \
  -net none -drive file=bootloader.img,format=raw,index=0,media=disk -S -s
