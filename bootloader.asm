;64-bit code
bits 64
;relative adresses
default rel

section .text
global start

.first_byte db 0x44
.second_byte db 0x22

start:
