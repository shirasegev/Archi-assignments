section	.rodata								; we define (global) read-only variables in .rodata section
    ; formats
	format_string: db "%s", 10, 0			; format string
	format_decimal: db "%d", 0  			; format decimal
	format_hexa: db "%02X", 10, 0			; format hexa
	format_float: db "%.2f", 0 			    ; format float. 2 digits after the decimal point.
    ; prompts
	new_line: db 10, 0
    comma: db ",", 0
    name: db "printer", 10, 0

section .data
    ; Definitions
	STKSZ 		equ 	16*1024				; Co-routine stack size 16k
	DROSZ		equ		37					; Size of one drone struct
	; Defines for all the co-routines
	CODEP		equ		0					; Offset of pointer to co-routine function in co-routine struct 
	FLAGSP		equ		4					; Offset of pointer to co-routine flags in co-routine struct 
	SPP			equ		8					; Offset of pointer to co-routine stack in co-routine struct 
	
	; Define for drones array
	XOFF		equ		12					; Offset in array for x
	YOFF		equ		16					; Offset in array for y
	SOFF		equ		20					; Offset in array for speed
	AOFF		equ		24					; Offset in array for angle
	NOFF		equ		28					; Offset in array for number of destroyed targers
	DIDOFF		equ		32					; Offset in array for drone Id
    ACTOFF      equ     36

section .bss								; we define (global) uninitialized variables in .bss section
    ; For printing float
	floatnum:			resd 1
	floatnum_dub:		resq 1

section .text
    global printer_co
    global printer_func

    extern printf

    extern target_x
	extern target_y
	extern co_scheduler_func
	extern co_target_func
	extern co_printer_func

    extern Nval
	extern Rval
	extern Kval
	extern angle
	extern Dval
	extern seed
	extern co_drones_stack
	extern co_drones_array

    extern CORS
	extern mayDestroy
    extern resume
;------------------------------------------------------------------------
%macro print_prompt 1
	pushad
	push %1
	call printf
	add esp, 4
	popad
%endmacro

%macro print 2
	pushad
	push %1
	push %2
	call printf
	add esp, 8
	popad
%endmacro

%macro print_float 1
	pushad
	mov [floatnum], %1
	fld dword [floatnum]
    fstp qword [floatnum_dub]
	push dword [floatnum_dub+4]  ;pushes 32 bits (MSB)
    push dword [floatnum_dub]    ;pushes 32 bits (LSB)
	push format_float
	call printf
	add esp, 12
	popad
%endmacro
;------------------------------------------------------------------------

; The function of a printer co-routine is as follows:

printer_co:
    ; push esp
    ; push ebp
    ; mov ebp, esp
    ; pushad


; (*) print the game board according to the format:
    ; All floating point numbers to be printed using %f or %lf with 2 digits after the decimal point,
    ; all angles to be printed in degrees (for readability).
    ; Each printed line should end with a newline character.
    ; The printing is in the following format:

    ; x,y	                               ; this is the current target coordinates
    mov eax, [target_x]
    print_float eax
    print_prompt comma
    mov eax, [target_y]
    print_float eax
    print_prompt new_line
    
    ; 1,x_1,y_1,α_1,speed_1,numOfDestroyedTargets_1    ; the first field is the drone id
    ; 2,x_2,y_2,α_2,speed_2,numOfDestroyedTargets_2    ; the fifth field is the number of targets destroyed by the drone
    ; …esp
    ; N,x_N,y_N,α_N,speed_N,numOfDestroyedTargets_N
    mov eax, [Nval]                                    ; Number of iterations
    mov ebx, 0
    mov ecx, [co_drones_array]                     ; ecx is the pointer to the begining of the drones_array
    print_drones_loop:
        cmp eax, ebx
        je loop_end
        
        cmp byte [ecx + ACTOFF], 0              ; check if the i'th droen is active
        je next

        mov edx, [ecx+DIDOFF]
        print edx, format_decimal
        print_prompt comma
        
        mov edx, [ecx+XOFF]
        print_float edx
        print_prompt comma

        mov edx, [ecx+YOFF]
        print_float edx
        print_prompt comma

        ; @TODO: Convert to angle
        mov edx, [ecx+AOFF]
        print_float edx
        print_prompt comma

        mov edx, [ecx+SOFF]
        print_float edx
        print_prompt comma

        mov edx, [ecx+NOFF]
        print edx, format_decimal
        print_prompt new_line

    next:
        add ecx, DROSZ
        inc ebx
        jmp print_drones_loop

    loop_end:
        print_prompt new_line
        ; pop esp
; (*) switch back to a scheduler co-routine
        mov ebx, [CORS]
        call dword resume
        jmp printer_co

;------------------------------------------------------------------------