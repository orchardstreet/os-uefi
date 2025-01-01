; See https://web.archive.org/web/20190706212328/https://gist.github.com/AdrianKoshka/5b6f8b6803092d8b108cda2f8034539a
; for creating a UEFI USB properly, then move bootx64.efi to /efi/usb on the first USB partition
;64-bit code
bits 64
;relative adresses
default rel

section .text
global start
; start of code

%macro UINTN 0
    RESQ 1
    alignb 8
%endmacro

%macro UINT32 0
    RESD 1
    alignb 4
%endmacro

%macro UINT64 0
    RESQ 1
    alignb 8
%endmacro

%macro EFI_HANDLE 0
    RESQ 1
    alignb 8
%endmacro

%macro POINTER 0
    RESQ 1
    alignb 8
%endmacro

; see http://www.uefi.org/sites/default/files/resources/UEFI Spec 2_7_A Sept 6.pdf#G8.1001729
struc EFI_TABLE_HEADER
    .Signature  UINT64
    .Revision   UINT32
    .HeaderSize UINT32
    .CRC32      UINT32
    .Reserved   UINT32
endstruc

; see http://www.uefi.org/sites/default/files/resources/UEFI Spec 2_7_A Sept 6.pdf#G8.1001773
struc EFI_SYSTEM_TABLE
    .Hdr                  RESB EFI_TABLE_HEADER_size
    .FirmwareVendor       POINTER
    .FirmwareRevision     UINT32
    .ConsoleInHandle      EFI_HANDLE
    .ConIn                POINTER
    .ConsoleOutHandle     EFI_HANDLE
    .ConOut               POINTER
    .StandardErrorHandle  EFI_HANDLE
    .StdErr               POINTER
    .RuntimeServices      POINTER
    .BootServices         POINTER
    .NumberOfTableEntries UINTN
    .ConfigurationTable   POINTER
endstruc

; see http://www.uefi.org/sites/default/files/resources/UEFI Spec 2_7_A Sept 6.pdf#G16.1016807
struc EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
    .Reset             POINTER
    .OutputString      POINTER
    .TestString        POINTER
    .QueryMode         POINTER
    .SetMode           POINTER
    .SetAttribute      POINTER
    .ClearScreen       POINTER
    .SetCursorPosition POINTER
    .EnableCursor      POINTER
    .Mode              POINTER
endstruc


start:
	;prolog
	; Save values UEFI firmware gave to us
	mov QWORD [stack_init], rsp ; Save return address, pop back before return
	mov QWORD [efi_handle], rcx ; Save EFI_HANDLE
	mov QWORD [system_table_ptr], rdx ; Save system table pointer
	;stack misaligned by 8
	sub rsp, 8 * 4 ; shadow space for called functions - start EVERY function prolog like this, with last number highest number of arguments of a called function within this function
	sub rsp, 8 ; align stack to 16 bytes

	; print_string(generic_message_str)
	mov rcx, generic_message_str
	call print_string
	cmp rax, 0
	je .start_print_string_successful
	jmp error_exit ;start print unsuccessful

	.start_print_string_successful:

	.start_exit:
	;epilog
		mov rax, 0
		mov rsp, QWORD [stack_init]
		jmp $
		retn



; prints a string using EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString()
print_string: ;in: rcx (address of string), out: rax (return value of OutputString)
	;prolog
	;stack misaligned by 8
	push rbp
	mov rbp, rsp
	mov QWORD [rbp + 16], rcx
	sub rsp, 4 * 8 ; shadow space

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	mov rdx, QWORD [rbp + 16]; assign passed rcx to rdx - second argument - address of string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
	; MICROSOFT FUNCTION CALL END

	;epilog
	add rsp, 4 * 8
	pop rbp
	ret

print_error_exit:
	;prolog
	sub rsp, 4 * 8 + 8

	mov rcx, generic_error_exit_str
	call print_string

error_exit:
	mov rax, 1
	mov rsp, QWORD [stack_init]
	jmp $
	retn



section .reloc ;UEFI supposedly requires this, even if empty



; "The registers Rax, Rcx Rdx R8, R9, R10, R11, and XMM0-XMM5 are volatile and are, therefore, destroyed on function calls.
;"The registers RBX, RBP, RDI, RSI, R12, R13, R14, R15, and XMM6-XMM15 are considered nonvolatile and must be saved and restored by a function that uses them."
; "https://uefi.org/specs/UEFI/2.10/02_Overview.html"
section .data
	stack_init dq 0
	system_table_ptr dq 0
	efi_handle dq 0
	generic_message_str db __utf16__ `\r\n\nnew message two :)\n\nHow are you all?\r\n\0`
	generic_message_str_two db __utf16__ `\r\n\ntwo new message two :)\n\nHow are you all?\r\n\0`
	generic_error_exit_str db __utf16__ `error encountered, exiting...\r\n\0`
