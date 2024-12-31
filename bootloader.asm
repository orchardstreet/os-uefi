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
	; Save values UEFI firmware gave to us
		mov QWORD [stack_init], rsp ; Save initial stack value
		mov QWORD [system_table_ptr], rdx ; Save system table pointer

	; print_string(generic_message_str)
		mov r8, generic_message_str
		call .print_string
		cmp rax, 0
		je .start_print_string_successful
		jmp .exit ;start print unsuccessful

	.start_print_string_successful:
		jmp $ ; loop forever

; prints a string using EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString()
; typically the arguments of a microsoft function are, in order: rcx, rdx, r8, r9
; but OutputString() only has two arguments, so we only need to set up rcx and rdx
.print_string: ;in: r8 (address of string), out: rax (return value of OutputString)
	; MICROSOFT FUNCTION CALL START
		call .get_value_to_adjust_rsp_around_ms_call ; return value is [rsp_adjustment]
		sub rsp, QWORD [rsp_adjustment] ;adjust rsp by return value of prior call
		mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
		mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
		mov rdx, r8 ; rdx is second argument - address of string
		call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
		add rsp, QWORD [rsp_adjustment] ;adjust by [rsp_adjustment]
	; MICROSOFT FUNCTION CALL END
	ret

.generic_error_exit: ;in: none, out: none
	mov r8, generic_error_exit_str
	call .print_string
.exit:
	mov rsp, QWORD [stack_init] ; Restore stack
	mov rax, 0
	retn

; Each x64 Microsoft function needs 32 BYTES OF SCRATCH SPACE BEFORE
; being called.  Also, RSP must be 16 byte aligned before such a call.
.get_value_to_adjust_rsp_around_ms_call: ; in: rsp,  out: [rsp_adjustment]
	mov QWORD [rsp_adjustment], 32; creating scratch space for four shadow arguments - necessary
		; rax % rcx = rdx; if rdx != 0 then rsp was misaligned
		xor rdx, rdx
		mov rax, rsp
		add rax, 8; check rsp from before this function, 8 was subtracted for the return value
		mov rcx, 16
		div rcx
		cmp rdx, 0
		je .get_value_to_adjust_rsp_around_ms_call_aligned
		add QWORD [rsp_adjustment], 8 ; rsp was misaligned, add 8 to scratch area so rsp will be aligned to 16 bytes
		.get_value_to_adjust_rsp_around_ms_call_aligned:
			ret

	

section .reloc ;UEFI supposedly requires this, even if empty

; https://web.archive.org/web/20170222171451/https://msdn.microsoft.com/en-us/library/9z1stfyw.aspx
; registers preserved across all x64 function calls: r12, r13, r14, r15, rdi, rsi, rbx, rbp
; microsft seems to prefer using r13-r15 in function prolog example code:
; https://learn.microsoft.com/en-us/cpp/build/prolog-and-epilog?view=msvc-170
section .data
	stack_init dq 0
	system_table_ptr dq 0
	rsp_adjustment dq 0
	generic_message_str db __utf16__ `\r\n\nnew message two :)\n\nHow are you all?\r\n\0`
	generic_error_exit_str db __utf16__ `error encountered, exiting...\r\n\0`
