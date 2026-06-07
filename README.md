# os-uefi

UEFI operating system written in x86 64-bit assembly

# Assemble

## Debian-based Linux
```
sudo apt update && sudo apt install lld dosfstools mtools clang nasm -y
chmod +x assemble-link-create-image.sh
./assemble-link-create-image.sh
```

### QEMU
```
sudo apt install qemu-system-x86 ovmf -y
```

## Alpine Linux
```
doas apk update && doas apk add mtools clang nasm
chmod +x assemble-link-create-image.sh
./assemble-link-create-image.sh
```
### QEMU
```
doas apk add qemu-system-x86_64 ovmf
```

