section	.rodata								; we define (global) read-only variables in .rodata section
	global CORS

	; formats
	format_string: 	db 	"%s", 10, 0			; format string
	format_decimal: db 	"%d", 10, 0			; format decimal
	format_hexa: 	db 	"%02X", 10, 0		; format hexa
	format_float: 	db 	"%f",10, 0 			; format float. 2 digits after the decimal point.
	format_i_float: db 	"%f", 0	 			; format float. 2 digits after the decimal point.
	; prompts
	new_line:		db 	10, 0

	CORS:
		dd	co_scheduler_func
		dd	co_target_func
		dd	co_printer_func
	CORS_END:

section .data
	global target_x
	global target_y
	global SPP
	global co_scheduler_func
	global co_target_func
	global co_printer_func

	global Dval

	co_scheduler_func: 	dd 	scheduler_co			; Pointer to function of scheduler
	co_scheduler_flags:	dd	0						; Flags of scheduler
	co_scheduler_sp:	dd	scheduler_stack+STKSZ	; Pointer to stack of scheduler
	co_target_func: 	dd	target_co				; Pointer to function of target
	co_target_flags:	dd	0						; Flags of target
	co_target_sp:	 	dd	target_stack+STKSZ		; Pointer to stack of target
	co_printer_func: 	dd 	printer_co				; Pointer to function of printer
	co_printer_flags:	dd	0						; Flags of printer
	co_printer_sp: 		dd 	printer_stack+STKSZ		; Pointer to stack of printer
	
	target_x: 			dd	0						; Position of target -- x
	target_y: 			dd	0						; Position of target -- y

	Dval: 				dd 	0.0						; d<float> – maximum distance that allows to destroy a target
	var1:				dd 	0.0						; temporary var
	var2: 				dd 	0.0						; temporary var
	var3:				dd	0.0						; temporary var

	; Definitions
	STKSZ 		equ 	3*1024				; Co-routine stack size 16k
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
	ACTOFF		equ		36					; Offser in array for active flag

	; Define for LFSR
	MSK16		equ		0x1					; Mask for the first bit
	MSK14		equ		0x4					; Mask for the third bit
	MSK13		equ		0x8					; Mask for the fourth bit
	MSK11		equ		0x20				; Mask for the sixth bit


section .bss								; we define (global) uninitialized variables in .bss section
    global Nval
	global Rval
	global Kval
	global CURR
	global co_drones_stack
	global co_drones_array
	global curr_drone
	global spmain
	global finish_main

	Nval: 				resd 	1			; N<int> – number of drones
    Rval: 				resd 	1			; R<int> - number of full scheduler cycles between each elimination
    Kval: 				resd 	1			; K<int> – how many drone steps between game board printings
	lfsr: 				resw 	1			; lfsr<short> - seed for initialization of LFSR shift register
	; Local parameters
	CURR: 				resd 	1			; CURR holds a pointer to co-init structure of the curent co-routine		
	spt: 				resd 	1			; Tempurary stack pointer
	spmain: 			resd 	1			; Stack pointer of main
	
	scheduler_stack:	resb	STKSZ		; Stack of scheduler
	printer_stack:		resb	STKSZ		; Stack of printer
	target_stack:		resb	STKSZ		; Stack of target
	; Pointer to dynamic data
	co_drones_stack:	resd	1			; Stack of all the co-routines
	co_drones_array:	resd	1			; Drones data array
	curr_drone:			resd	1

	; For printing float
	floatnum:			resd 1
	floatnum_dub:		resq 1


section .text
    ;global _start
	global main
	global mayDestroy
	global generate_pseudo_random_number
	global get_random_pos
	global get_random_speed
	global get_random_angle
	global createTarget
	global quit

	global get_random_delta_angle
	global get_random_delta_speed
	global convert_degrees_to_radians
	global convert_radians_to_degrees

	extern scheduler_co
	extern target_co
	extern printer_co
	extern printer_func
	extern drone_co

    extern printf
    extern fprintf
    extern sscanf
    extern malloc
    extern calloc
    extern free

	global resume
	global do_resume

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

%macro get_arg_val 2
	pushad
	push %1
	push format_decimal
	push dword %2
	call sscanf
	add esp, 12
	popad
%endmacro
%macro get_arg_val_float 2
	pushad
	push dword %1
	push format_i_float
	push dword %2
	call sscanf
	add esp, 12
	popad
%endmacro
;------------------------------------------------------------------------
_start:
    pop    dword ecx    		; ecx = argc
    mov    esi,esp      		; esi = argv
    ;; lea eax, [esi+4*ecx+4] 	; eax = envp = (4*ecx)+esi+4
    mov     eax,ecx     		; put the number of arguments into eax
    shl     eax,2       		; compute the size of argv in bytes
    add     eax,esi   			; add the size to the address of argv 
    add     eax,4     			; skip NULL at the end of argv
    push    dword eax  		 	; char *envp[]
    push    dword esi  			; char* argv[]
    push    dword ecx   		; int argc

    call    main        		; int main( int argc, char *argv[], char *envp[] )

    mov     ebx,eax
    mov     eax,1
    int     0x80        		; Transfer control to operating system
    nop
;------------------------------------------------------------------------
main:	
	; Command line arguments:
	push    ebp             				; Save caller state
	mov     ebp, esp
	mov ecx, dword [ebp+12]					; get **argv

	finit

	get_arg_val Nval, [ecx+4]			; N<int> – number of drones
	get_arg_val Rval, [ecx+8]			; R<int> - number of full scheduler cycles between each elimination
	get_arg_val Kval, [ecx+12]			; K<int> – how many drone steps between game board printings
	get_arg_val_float Dval, [ecx+16]	; d<float> – maximum distance that allows to destroy a target
	get_arg_val lfsr, [ecx+20]			; seed<int> - seed for initialization of LFSR shift register	

	; Init a drones stack with size N*16K
	mov eax, STKSZ							; For the drones
	mov ebx, [Nval]							; Size of each co-routine
	mul ebx									; stack = STKSZ * N
	push eax								; Ans of mul in edx-eax, we assume the ans is up to 32bit so it only in eax
	call malloc
	add esp, 4								
	mov [co_drones_stack], eax				; Address where malloc located is in eax

	; Init a drones array
	mov eax, DROSZ							; Each drone takes DROSZ size
	mov ebx, [Nval]							; We have N drones
	mul ebx									; drone_array = DROSZ * N
	push eax								; Ans of mul in edx-eax, we assume the ans is up to 32bit so it only in eax
	call malloc
	add esp, 4
	mov [co_drones_array], eax				; Address where malloc located is in eax
	
	; Init CORES state
	call co_init
	; Now all the co-routines are initialized
	mov [spmain], esp
	mov dword [curr_drone], 0			; Curr drone will hold the first drone ID
	mov ebx, [CORS]						; Ebx is pointer to scheduler function
	jmp do_resume

	finish_main:
		mov 	esp, [spmain]
		call quit
		pop     ebp             			; Restore caller state
		ret                     			; Back to caller

;------------------------------------------------------------------------
co_init:
	push ebp
	mov ebp, esp 
	pushad 
	
	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	mov ecx, CORS							; Getting the first argument into ecx

	co_init_loop:

		mov ebx, [ecx]
		; Ebx is pointer to co-routine structure to initialize
		mov eax, [ebx+CODEP]
		mov [spt], esp						; Save old SP
		mov esp, [ebx+SPP]
		push eax							; Push initial "return" address
		pushfd								; Push flags
		pusha                   			; and all other regs
		mov	[ebx+SPP],esp					; Save new SP in structure
		mov	esp, [spt]						; Restore original SP
		mov edx, CORS
		add edx, 8
		cmp edx, ecx

		; cmp ecx, CORS_END
		je co_init_done
		add ecx, 4
		jmp co_init_loop

	co_init_done:
		; Init target X and Y
		call createTarget

		mov ebx, [co_drones_array]
		; Ebx is pointer to drones structure to initialize
		mov ecx, [co_drones_stack]
		; Ecx isget_random_pos pointer to drones end of stack
		mov edx, 0
		; Edx is the i's drone
	co_init_drones:
	
		; Init struct parameters
		mov dword [ebx+CODEP], drone_co		; Init CODEP to point the func drone_co
		mov dword [ebx+FLAGSP], 0			; Init FLAGSP to 0
		add ecx, STKSZ						; Every drone pointer will point to the end of the stack
		mov dword [ebx+SPP], ecx			; SPP point to stack segment start
		call get_random_pos					; eax hold the new pos
		mov dword [ebx+XOFF], eax			; Init Xval
		call get_random_pos					; eax hold the new pos
		mov dword [ebx+YOFF], eax			; Init Yval
		call get_random_speed
		mov dword [ebx+SOFF], eax			; Init speed to 0
		call get_random_angle
		mov dword [ebx+AOFF], eax			; Init angle to 0
		mov dword [ebx+NOFF], 0				; Init number of destroyed targers to 0
		mov dword [ebx+DIDOFF], edx			; Drone ID
		mov byte [ebx+ACTOFF], 1			; Active flag
		
		; Init drones state
		; mov eax, drone_co; [ebx+CODEP]
		mov [spt], esp						; Save old SP
		mov esp, [ebx+SPP]
		push drone_co						; Push initial "return" address
		pushfd								; Push flags
		pusha                   			; and all other regs
		mov	[ebx+SPP],esp				    ; Save new SP in structure
		mov	esp, [spt]					 	; Restore original SP
		
		inc edx	; Increment drone counter before checking as it should be <N

		mov eax, [Nval]
		cmp eax, edx
		je done_init

		add ebx, DROSZ
		jmp co_init_drones

	done_init:
		popad 
		mov esp, ebp 
		pop ebp
		ret


;------------------------------------------------------------------------
; EBX is pointer to co-init structure of co-routine to be resumed
; CURR holds a pointer to co-init structure of the curent co-routine
resume:
	pushfd					; Save state of caller
	pushad	
	mov	edx, [CURR]
	mov	[edx+SPP], esp		; Save current SP

do_resume:
	mov	esp, [ebx+SPP]  	; Load SP for resumed co-routine
	mov	[CURR], ebx
	popad					; Restore resumed co-routine state
	popfd
	ret                     ; "return" to resumed co-routine!

; End co-routine mechanism, back to main
end_co:
	mov		ebp, [spmain]				; Restore state of main code
	mov     eax, [ebp-4]    			; place returned value where caller can see it
	popa
	pop     ebp             			; Restore caller state
	ret                     			; Back to caller
;------------------------------------------------------------------------
; After each movement, a drone calls the mayDestroy(…) function with its new position on the board.
; The mayDestroy(…) function returns TRUE if the caller drone may destroy the target,
;  otherwise returns FALSE
; input: drone number
; output: may destroy
; return: boolean -- 1 = true ; 0 = false
mayDestroy:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0

	; we need to calculate:
	; distance = sqrt((target_x-drone_x)^2 + (target_y-drone_y)^2)
	mov ecx, dword [ebp+8]				; Getting the first argument into ecx

	mov ebx, [co_drones_array]			; ebx is pointer to drones array
	mov eax, DROSZ
	mul ecx								; eax now is offset to specific drone
	add ebx, eax						; ebx is pointer to specific drone
	ffree

	fld dword [ebx+XOFF]
	fsub dword [target_x]
	fst st1
	fmulp
	fstp dword [var1]					; var1 = (target_x - drone_x)^2
	mov eax, [var1]

	fld dword [ebx+YOFF]
	fsub dword [target_y]
	fst st1
	fmulp								; stack = (target_y - drone_y)^2
	fadd dword [var1]					; stack = (target_y - drone_y)^2 + (target_x - drone_x)^2
	fsqrt

	; compare distance with dval and return true or false accordingly
	fsub dword [Dval]					; stack = distance - D
	fldz
	fcomip								; if (stack <= 0)
	jae return_true
	; else - return_false
	popad
	mov eax, 0							; false == 0
	mov esp, ebp
	pop ebp
	ret
	return_true:
		popad
		mov eax, 1							; true == 1
		mov esp, ebp
		pop ebp
		ret

;------------------------------------------------------------------------
; (*) calculate a random x coordinate
; (*) calculate a random y coordinate
createTarget:
	push ebp
	mov ebp, esp
	pushad

	call get_random_pos					; eax hold the new pos
	mov [target_x], eax
	call get_random_pos					; eax hold the new pos
	mov [target_y], eax

	popad
	mov esp, ebp
	pop ebp
	ret
;------------------------------------------------------------------------
	;
	;	  1										  11	  13  14      16
	;	 _______________________________________________________________ 
	;	| 1 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 1 | 
	;														  ^		  1
	;													  ^	  1	 <-  <-
	;											  ^			  =
	;											  			  1
	;													  1  <-
	;													  =
	;													  1
	;											  1	 <-  <-
	;											  =
	;											  0
	;	  0	 <-	 <-	 <-	 <-	 <-	 <-	 <-	 <-	 <-	 <-
	;	 _______________________________________________________________ 
	;	| 0 | 1 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 
	;
generate_pseudo_random_number:
	push ebp
	mov ebp, esp
	pushad

	mov eax, 0
	mov ebx, 0
	mov ecx, 16				; Cx will be the loop counter
	mov edx, 0				
	mov ax, [lfsr]			; Ax have the current pos of LFSR

	generator_loop:

		mov bx, MSK16
		and bx, ax				; Bx have the 16th bit

		shl bx, 2				; Bx bit is in the same place where 14th bit is
		mov dx, MSK14
		and dx, ax				; Dx have the 14th bit
		xor bx, dx				; Bx have the ans of first xor

		shl bx, 1				; Bx bit is in the same place where 13th bit is
		mov dx, MSK13
		and dx, ax				; Dx have the 13th bit
		xor bx, dx				; Bx have the ans of second xor

		shl bx, 2				; Bx bit is in the same place where 11th bit is
		mov dx, MSK11
		and dx, ax				; Dx have the 13th bit
		xor bx, dx				; Bx have the ans of third xor

		shl bx, 10				; Bx bit is in the last position where he need to enter
		shr ax, 1				; Ax shift once to right and make space for the new bit
		or ax, bx				; Ax have the new LFSR reg
		
		loop generator_loop, ecx
		
		mov [lfsr], ax			; Store LFSR
		
		popad
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
get_random_pos:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	call generate_pseudo_random_number
	mov ax, [lfsr]
	ffree
	mov dword [var1], 0
	mov [var1], ax
	fld dword [var1]			; load x
	
	mov dword [var2], 65535		; MAXSHORT
	fdiv dword [var2]			; getting x / MAXSHORT
	
	mov eax, 100
	mov dword [var1], eax		; range
	fimul dword [var1]			; (x / MAXINT) * 100
	
	mov dword [var1], 0
	fstp dword [var1]			; var1 hold the ans

	
	popad
	mov eax, [var1]				; eax hold the ans
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
get_random_angle:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	call generate_pseudo_random_number
	mov ax, [lfsr]
	mov dword [var1], 0
	mov [var1], ax
	fld dword [var1]			; load x
	
	mov dword [var2], 65535		; MAXSHORT
	fdiv dword [var2]			; getting x / MAXSHORT
	
	mov dword [var1], 360		; range is now [0,360]
	fimul dword [var1]			; (x / MAXINT) * 360
	
	mov dword [var1], 0
	fstp dword [var1]			; var1 hold the ans

	popad
	mov eax, [var1]				; eax hold the ans
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
get_random_delta_angle:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	call generate_pseudo_random_number
	mov ax, [lfsr]
	mov dword [var1], 0
	mov [var1], ax
	fld dword [var1]			; load x
	
	mov dword [var2], 65535		; MAXSHORT
	fdiv dword [var2]			; getting x / MAXSHORT
	
	mov dword [var1], 120		; range is now [0,120]
	fimul dword [var1]			; (x / MAXINT) * 120

	mov dword [var1], 60		; range is now [-60,60]
	fisub dword [var1]			; ((x / MAXINT) * 120) - 60
	
	mov dword [var1], 0
	fstp dword [var1]			; var1 hold the ans

	popad
	mov eax, [var1]				; eax hold the ans
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
get_random_speed:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	call generate_pseudo_random_number
	mov ax, [lfsr]
	mov dword [var1], 0
	mov [var1], ax
	fld dword [var1]			; load x
	
	mov dword [var2], 65535		; MAXSHORT
	fdiv dword [var2]			; getting x / MAXSHORT
	
	mov dword [var1], 100		; range is now [0,100]
	fimul dword [var1]			; (x / MAXINT) * 100
	
	mov dword [var1], 0
	fstp dword [var1]			; var1 hold the ans

	popad
	mov eax, [var1]				; eax hold the ans
	mov esp, ebp
	pop ebp
	ret
;------------------------------------------------------------------------
get_random_delta_speed:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0

	call generate_pseudo_random_number
	mov ax, [lfsr]
	mov dword [var1], 0
	mov [var1], ax
	fld dword [var1]			; load x
	
	mov dword [var2], 65535		; MAXSHORT
	fdiv dword [var2]			; getting x / MAXSHORT
	
	mov dword [var1], 20		; range is now [0,20]
	fimul dword [var1]			; (x / MAXINT) * 20

	mov dword [var1], 10		; range is now [-10,10]
	fisub dword [var1]			; ((x / MAXINT) * 20) - 10
	
	mov dword [var1], 0
	fstp dword [var1]			; var1 hold the ans

	popad
	mov eax, [var1]				; eax hold the ans
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
; (degree / 180) * pi = degree
; input: angle in degrees
; output: angle in radians
; return: float
convert_degrees_to_radians:
	push ebp
	mov ebp, esp
	pushad

	mov eax, 0
	mov ebx, 0
	mov ecx, 0
	mov edx, 0
	mov dword [var1], 0
	mov dword [var2], 0
	mov dword [var3], 0

	ffree
	mov ecx, dword [ebp+8]			; Getting the first argument into ecx
	mov [var1], ecx
	fld dword [var1]				; Push degrees angle
	mov dword [var2], 180
	fidiv dword [var2]				; Stack = degree / 180
	fldpi							; Push pi
	fmulp							; Stack = (degree / 180) * pi
	fstp dword [var3]

	popad
	mov eax, [var3]
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
; (rad / pi) * 180 = degree
; input: angle in radians
; output: angle in degrees
; return: float
convert_radians_to_degrees:
	push ebp
	mov ebp, esp
	pushad

	mov eax,0
	mov ebx,0
	mov ecx,0
	mov edx,0
	mov dword [var1], 0
	mov dword [var2], 0
	mov dword [var3], 0

	ffree
	mov ecx, dword [ebp+8]			; Getting the first argument into ecx
	mov [var1], ecx
	fld dword [var1]				; Push rad angle
	fldpi							; Push pi
	fdivp							; Stack = rad / pi
	mov dword [var2], 180
	fimul dword [var2]				; Stack = (rad / pi) * 180
	fstp dword [var3]

	popad
	mov eax, [var3]
	mov esp, ebp
	pop ebp
	ret

;------------------------------------------------------------------------
quit:
	push ebp
	mov ebp, esp
	pushad

	; free all allocated memory:
	mov ebx, [co_drones_array]
	push ebx
	call free
	add esp, 4

	mov ebx, [co_drones_stack]
	push ebx
	call free
	add esp, 4

	; and exit
	popad
	mov esp, ebp
	pop ebp
	ret