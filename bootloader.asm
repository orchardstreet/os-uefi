; See https://web.archive.org/web/20190706212328/https://gist.github.com/AdrianKoshka/5b6f8b6803092d8b108cda2f8034539a
; for creating a UEFI USB properly, then move bootx64.efi to /efi/usb on the first USB partition
;64-bit code
bits 64
;relative adresses
default rel

section .text
global start


; Start of program
;callable functions: print_string, fun_func
;noreturn functions: print_error_exit
;noreturn subroutine: error_exit
start:
	;prolog
	;stack misaligned by 8
	sub rsp, 4 * 8 ; shadow space for called functions - start EVERY function prolog like this, with first number highest number of arguments of a called function within this function
	sub rsp, 8 ; align stack to 16 bytes

	; Save values UEFI firmware gave to us
	mov QWORD [stack_init], rsp ; Save return address, pop back before return
	mov QWORD [efi_handle], rcx ; Save EFI_HANDLE
	mov QWORD [system_table_ptr], rdx ; Save system table pointer

	jmp $
	mov eax, EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL_size
	mov eax, EFI_SYSTEM_TABLE_size
	mov eax, EFI_TABLE_HEADER_size

	; Reset screen
	mov rcx, 0 ;argument for reset screen, no verification (verification can take a long time)
	call reset_screen
	cmp rax, 0
	je .reset_screen_successful_1
	jmp error_exit
	.reset_screen_successful_1:

	; Print generic message
	; print_string(generic_message_str)
	mov rcx, generic_message_str
	call print_string
	cmp rax, 0
	je .start_print_string_successful_1
	jmp error_exit
	.start_print_string_successful_1:

	call fun_func

	.start_exit:
		jmp $
		mov rax, 0
	;epilog
		;mov rsp, QWORD [stack_init]
		add rsp, 4 * 8 + 8
		retn

; sets cursor position to 0,0, clears screen to default background color, and optionally performs verification
; of device functioning
reset_screen: ;in: rcx (0 for no verification, 1 for verification), out: rax
	sub rsp, 4 * 8 + 8

	mov QWORD [rsp + 48], rcx ;store in shadow space for rcx lmao; https://www.scss.tcd.ie/jeremy.jones/CSU34021/2%20IA32%20+%20x64.pdf page 39

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	mov rdx, QWORD [rsp + 48]; assign passed rcx to rdx - second argument - 0 for no verification, 1 for verification
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.Reset]
	; MICROSOFT FUNCTION CALL END

	add rsp, 4 * 8 + 8

; clears the screen with currently set background color
clear_screen:
	sub rsp, 4 * 8 + 8

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.ClearScreen]
	; MICROSOFT FUNCTION CALL END

	add rsp, 4 * 8 + 8

; prints a string using EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString()
print_string: ;in: rcx (address of string), out: rax (return value of OutputString)
	;prolog
	;stack misaligned by 8
	sub rsp, 4 * 8 + 8 ; shadow space + align to 16 bytes

	mov QWORD [rsp + 48], rcx ;store in shadow space for rcx lmao; https://www.scss.tcd.ie/jeremy.jones/CSU34021/2%20IA32%20+%20x64.pdf page 39

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	mov rdx, QWORD [rsp + 48]; assign passed rcx to rdx - second argument - address of string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
	; MICROSOFT FUNCTION CALL END

	;epilog
	add rsp, 4 * 8 + 8
	ret

; noreturn function
print_error_exit:
	;prolog
	;stack misaligned by 8
	sub rsp, 4 * 8 + 8 ; shadow space + align to 16 bytes

	mov rcx, generic_error_exit_str
	call print_string
error_exit:
	jmp $
	mov rax, 1
	mov rsp, QWORD [stack_init]
	retn

fun_func:
	;prolog
	sub rsp, 4 * 8 + 8

	; print_string(generic_message_str)
	mov rcx, generic_message_str_two
	call print_string
	cmp rax, 0
	je .fun_func_successful_1
	jmp error_exit
	.fun_func_successful_1:

	;epilog
	add rsp, 4 * 8 + 8


section .reloc ;UEFI supposedly requires this, even if empty

; "The registers Rax, Rcx Rdx R8, R9, R10, R11, and XMM0-XMM5 are volatile and are, therefore, destroyed on function calls.
;"The registers RBX, RBP, RDI, RSI, R12, R13, R14, R15, and XMM6-XMM15 are considered nonvolatile and must be saved and restored by a function that uses them."
; "https://uefi.org/specs/UEFI/2.10/02_Overview.html"
section .data align=16
	stack_init dq 0
	system_table_ptr dq 0
	efi_handle dq 0


section .rdata align=16
	%macro UINTN 0
	    RESQ 1
	%endmacro

	%macro UINT32 0
	    RESD 1
	%endmacro

	%macro UINT64 0
	    RESQ 1
	%endmacro

	%macro EFI_HANDLE 0
	    RESQ 1
	%endmacro

	%macro POINTER 0
	    RESQ 1
	%endmacro

	%macro UINTN_ALIGN 0
	    alignb 8
	%endmacro

	%macro UINT32_ALIGN 0
	    alignb 4
	%endmacro

	%macro UINT64_ALIGN 0
	    alignb 8
	%endmacro

	%macro EFI_HANDLE_ALIGN 0
	    alignb 8
	%endmacro

	%macro POINTER_ALIGN 0
	    alignb 8
	%endmacro

	struc EFI_TABLE_HEADER ;nasm sees this as 24 bytes
		UINT64_ALIGN
		.Signature  UINT64
		UINT32_ALIGN
		.Revision   UINT32
		UINT32_ALIGN
		.HeaderSize UINT32
		UINT32_ALIGN
		.CRC32      UINT32
		UINT32_ALIGN
		.Reserved   UINT32
		resb (($ - EFI_TABLE_HEADER.Signature) % 8)
	endstruc

	struc EFI_SYSTEM_TABLE ;nasm sees this as 120 bytes
		POINTER_ALIGN
		.Hdr                  resb EFI_TABLE_HEADER_size ;24
		POINTER_ALIGN
		.FirmwareVendor       POINTER ;8
		UINT32_ALIGN
		.FirmwareRevision     UINT32 ;4
		EFI_HANDLE_ALIGN
		.ConsoleInHandle      EFI_HANDLE ;8
		POINTER_ALIGN
		.ConIn                POINTER ;8
		EFI_HANDLE_ALIGN
		.ConsoleOutHandle     EFI_HANDLE ;8
		POINTER_ALIGN
		.ConOut               POINTER ;8
		EFI_HANDLE_ALIGN
		.StandardErrorHandle  EFI_HANDLE ;8
		POINTER_ALIGN
		.StdErr               POINTER ;8
		POINTER_ALIGN
		.RuntimeServices      POINTER ;8
		POINTER_ALIGN
		.BootServices         POINTER ;8
		UINTN_ALIGN
		.NumberOfTableEntries UINTN ;8
		POINTER_ALIGN
		.ConfigurationTable   POINTER ;8
		resb (($ - EFI_SYSTEM_TABLE.Hdr) % 8) ;this is actually padding 4 bytes so it is working
	endstruc

	struc EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL ;nasm sees this as 80 bytes
		POINTER_ALIGN
		.Reset             POINTER
		POINTER_ALIGN
		.OutputString      POINTER
		POINTER_ALIGN
		.TestString        POINTER
		POINTER_ALIGN
		.QueryMode         POINTER
		POINTER_ALIGN
		.SetMode           POINTER
		POINTER_ALIGN
		.SetAttribute      POINTER
		POINTER_ALIGN
		.ClearScreen       POINTER
		POINTER_ALIGN
		.SetCursorPosition POINTER
		POINTER_ALIGN
		.EnableCursor      POINTER
		POINTER_ALIGN
		.Mode              POINTER
		resb (($ - EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.Reset) % 8)
	endstruc

	generic_message_str db __utf16__ `\rOS-UEFI BOOTLOADER v0.1\r\n\0`
	generic_message_str_two db __utf16__ `\rCopyright William Lupinacci\r\n\0`
	generic_error_exit_str db __utf16__ `error encountered, exiting...\r\n\0`
