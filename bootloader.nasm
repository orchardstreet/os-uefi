;callable functions: print_string
;noreturn functions: print_error_exit
;noreturn subroutine: error_exit
; See https://web.archive.org/web/20190706212328/https://gist.github.com/AdrianKoshka/5b6f8b6803092d8b108cda2f8034539a
; for creating a UEFI USB properly, then move bootx64.efi to /efi/usb on the first USB partition
;64-bit code
bits 64
;relative adresses
default rel

section .text
global start

; ################# START OF PROGRAM #######################
start:
	;prologue
	;stack misaligned by 8
	sub rsp, 4 * 8 ; shadow space for called functions - start EVERY function prologue like this, with first number highest number of arguments of a called function within this function
	sub rsp, 8 ; align stack to 16 bytes

	; Save values UEFI firmware gave to us
	mov QWORD [stack_init], rsp ; Save return address, pop back before return
	mov QWORD [efi_handle], rcx ; Save EFI_HANDLE
	mov QWORD [system_table_ptr], rdx ; Save system table pointer

	; Clear screen
	call clear_screen
	cmp rax, 0
	je .clear_screen_successful_1
	jmp error_exit
	.clear_screen_successful_1:

	; Print generic message
	; print_string(generic_message_str)
	mov rcx, generic_message_str
	call print_string
	cmp rax, 0
	je .start_print_string_successful_1
	jmp error_exit
	.start_print_string_successful_1:

; ########## CONTINUE HERE ###############

	; Start GOP
	call gop_start
	cmp rax, 0
	je .gop_started
	; Print Graphics Device not found and exit
	mov rcx, gop_error_str
	call print_string
	jmp error_exit
	.gop_started:

	; Print GOP started
	mov rcx, gop_started_str
	call print_string
	cmp rax, 0
	je .start_print_string_successful_2
	jmp error_exit
	.start_print_string_successful_2:


; ########## EXIT PROGRAM ################

	.exit:
		jmp $
		mov rax, 0
		;mov rsp, QWORD [stack_init]
		add rsp, 4 * 8 + 8
		retn

; ############## SUBROUTINES #########################33

; clears the screen with currently set background color
clear_screen:
	sub rsp, 4 * 8 + 8

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.ClearScreen]
	; MICROSOFT FUNCTION CALL END

	add rsp, 4 * 8 + 8
	ret

gop_start:
	sub rsp, 4 * 8 + 8

	mov r10, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov r10, QWORD [r10 + EFI_SYSTEM_TABLE.BootServices]
	mov rcx, graphics_output_protocol_guid
	mov rdx, 0
	mov r8, efi_graphics_output_protocol_struc_ptr 
	call [r10 + EFI_BOOT_SERVICES.LocateProtocol]

	; MICROSOFT FUNCTION CALL END
	add rsp, 4 * 8 + 8
	ret

; prints a string using EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString()
print_string: ;in: rcx (address of string), out: rax (return value of OutputString)
	;prologue
	;stack misaligned by 8
	sub rsp, 4 * 8 + 8 ; shadow space + align to 16 bytes

	mov QWORD [rsp + 48], rcx ;store in shadow space for rcx lmao; https://www.scss.tcd.ie/jeremy.jones/CSU34021/2%20IA32%20+%20x64.pdf page 39

	; MICROSOFT FUNCTION CALL START
	mov rcx, QWORD [system_table_ptr] ; rcx is first argument - pointer to EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov rcx, QWORD [rcx + EFI_SYSTEM_TABLE.ConOut]
	mov rdx, QWORD [rsp + 48]; assign passed rcx to rdx - second argument - address of string
	call [rcx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL.OutputString]
	; MICROSOFT FUNCTION CALL END

	;epilogue
	add rsp, 4 * 8 + 8
	ret

; noreturn function
print_error_exit:
	;prologue
	;stack misaligned by 8
	sub rsp, 4 * 8 + 8 ; shadow space + align to 16 bytes

	mov rcx, generic_error_exit_str
	call print_string
error_exit:
	jmp $
	mov rax, 1
	mov rsp, QWORD [stack_init]
	retn

	;epilogue
	add rsp, 4 * 8 + 8


section .reloc ;UEFI supposedly requires this, even if empty



; ######## DATA #########################
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
		.Signature  UINT64
		UINT32_ALIGN
		.Revision   UINT32
		UINT32_ALIGN
		.HeaderSize UINT32
		UINT32_ALIGN
		.CRC32      UINT32
		UINT32_ALIGN
		.Reserved   UINT32
		alignb 8
	endstruc

	struc EFI_SYSTEM_TABLE ;nasm sees this as 120 bytes
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
		alignb 8
	endstruc

	struc EFI_BOOT_SERVICES
		.Hdr			   resb EFI_TABLE_HEADER_size ;24	
		POINTER_ALIGN
		.RaiseTPL		   POINTER
		POINTER_ALIGN
		.RestoreTPL		   POINTER
		POINTER_ALIGN
		.AllocatePages	   POINTER
		POINTER_ALIGN
		.FreePages		   POINTER
		POINTER_ALIGN
		.GetMemoryMap      POINTER
		POINTER_ALIGN
		.AllocatePool	   POINTER
		POINTER_ALIGN
		.FreePool		   POINTER
		POINTER_ALIGN
		.CreateEvent	   POINTER
		POINTER_ALIGN
		.SetTime		   POINTER
		POINTER_ALIGN
		.WaitForEvent	   POINTER
		POINTER_ALIGN
		.SignalEvent	   POINTER
		POINTER_ALIGN
		.CloseEvent	       POINTER
		POINTER_ALIGN
		.CheckEvent        POINTER
		POINTER_ALIGN
		.InstallProtocolInterface    POINTER
		POINTER_ALIGN
		.ReinstallProtocolInterface  POINTER
		POINTER_ALIGN
		.UninstallProtocolInterface  POINTER
		POINTER_ALIGN
		.HandleProtocol    POINTER
		POINTER_ALIGN
		.Reserved	       POINTER
		POINTER_ALIGN
		.RegisterProtcolNotify       POINTER
		POINTER_ALIGN
		.LocateHandle	   POINTER
		POINTER_ALIGN
		.LocateDevicePath  POINTER
		POINTER_ALIGN
		.InstallConfigurationTable   POINTER
		POINTER_ALIGN
		.LoadImage         POINTER
		POINTER_ALIGN
		.StartImage        POINTER
		POINTER_ALIGN
		.Exit              POINTER
		POINTER_ALIGN
		.UnloadImage       POINTER
		POINTER_ALIGN
		.ExitBootServices  POINTER
		POINTER_ALIGN
		.GetNextMonotonicCount       POINTER
		POINTER_ALIGN
		.Stall             POINTER
		POINTER_ALIGN
		.SetWatchdogTimer  POINTER
		POINTER_ALIGN
		.ConnectController POINTER
		POINTER_ALIGN
		.DisconnectController        POINTER
		POINTER_ALIGN
		.OpenProtocol      POINTER
		POINTER_ALIGN
		.CloseProtocol     POINTER
		POINTER_ALIGN
		.OpenProtocolInformation     POINTER
		POINTER_ALIGN
		.ProtocolsPerHandle          POINTER
		POINTER_ALIGN
		.LocateHandleBuffer          POINTER
		POINTER_ALIGN
		.LocateProtocol              POINTER
		POINTER_ALIGN
		.InstallMultipleProtocolInterfaces    POINTER
		POINTER_ALIGN
		.UninstallMultipleProtocolInterfaces  POINTER
		POINTER_ALIGN
		.CalculateCRC32    POINTER
		POINTER_ALIGN
		.CopyMem           POINTER
		POINTER_ALIGN
		.SetMem            POINTER
		POINTER_ALIGN
		.CreateEventEx     POINTER
		alignb 8
	endstruc

	struc EFI_GRAPHICS_OUTPUT_PROTOCOL
		.QueryMode		POINTER
		POINTER_ALIGN
		.SetMode		POINTER
		POINTER_ALIGN
		.Blt			POINTER
		POINTER_ALIGN
		.Mode			POINTER
		alignb 8
	endstruc

	struc EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL ;nasm sees this as 80 bytes
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
		alignb 8
	endstruc

	gop_started_str db __utf16__ `\rGOP Started...\r\n\0`
	gop_error_str db __utf16__ `\rCould not find a Graphics Device, please insert\r\na GPU or use an Intel iGPU\r\n\0`
	generic_message_str db __utf16__ `\rOS-UEFI BOOTLOADER v0.1\r\n\0`
	generic_error_exit_str db __utf16__ `\rerror encountered, exiting...\r\n\0`
	alignb 4
	graphics_output_protocol_guid:
	dd 0x9042a9de
	dw 0x23dc
	dw 0x4a38
	db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a

	section .bss
	alignb 8
	efi_graphics_output_protocol_struc_ptr resb EFI_GRAPHICS_OUTPUT_PROTOCOL_size

; "The registers Rax, Rcx Rdx R8, R9, R10, R11, and XMM0-XMM5 are volatile and are, therefore, destroyed on function calls.
;"The registers RBX, RBP, RDI, RSI, R12, R13, R14, R15, and XMM6-XMM15 are considered nonvolatile and must be saved and restored by a function that uses them."
; "https://uefi.org/specs/UEFI/2.10/02_Overview.html"
