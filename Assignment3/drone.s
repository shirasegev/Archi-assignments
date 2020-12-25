section	.rodata								; we define (global) read-only variables in .rodata section
; formats
	format_string: db "%s", 10, 0			; format string
	format_decimal: db "%d", 10, 0			; format decimal
	format_hexa: db "%02X", 10, 0			; format hexa
	format_float: db "%.2f", 10, 0 			; format float. 2 digits after the decimal point.
; prompts
	new_line: db 10, 0
	name: db "drone %d", 10, 0

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
	ACTOFF		equ		36					

	var1:				dd 	0.0						; temporary var
	var2: 				dd 	0.0						; temporary var
	var3:				dd	0.0						; temporary var

section .bss
	delta_a: 			resd 1
	delta_s: 			resd 1
	; For printing float
	floatnum:			resd 1
	floatnum_dub:		resq 1

section .text
    global drone_co

	extern mayDestroy
	extern resume
	extern co_scheduler_func
	extern co_target_func
	extern co_printer_func
	extern generate_pseudo_random_number
	extern get_random_pos
	extern get_random_delta_speed
	extern get_random_delta_angle
	extern convert_radians_to_degrees
	extern convert_degrees_to_radians

    extern printf
    extern Nval
	extern Rval
	extern Kval
	extern angle
	extern Dval
	extern co_drones_stack
	extern co_drones_array
    extern active_drones
	extern curr_drone

	extern CORS

	extern CURR
	extern co_schedulerprint
	extern drones_array
	extern co_drones_array
	extern co_target
	extern targetX
	extern targetY
	extern co_printer

;------------------------------------------------------------------------
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

; The function of a drone co-routine is as follows:
drone_co:
	mov eax, [curr_drone]
	; print eax, name
	mov ebx, DROSZ
	mul ebx
	mov edx, [co_drones_array]
	add edx, eax						; edx is the pointer to curr_drone data

	mov ecx, [edx + DIDOFF]

; (*) calculate random heading change angle  ∆α       ; generate a random number in range [-60,60] degrees, with 16 bit resolution
	call get_random_delta_angle
	mov [delta_a], eax
	
; (*) calculate random speed change ∆a         ; generate random number in range [-10,10], with 16 bit resolution
	call get_random_delta_speed
	mov [delta_s], eax

; (*) calculate a new drone position:
	push edx
	call calc_new_pos
	add esp, 4

; (*) while mayDestroy(…) to check if a drone may destroy the target
    mayDestroy_loop:
		; check if may destroy
		mov eax, [edx + DIDOFF]
		push eax
		call mayDestroy
		add esp, 4
		cmp eax, 0
		je end_of_loop

;     (*) destroy the target
		mov eax, [edx + NOFF]
		inc eax
		mov [edx + NOFF], eax	
;     (*) resume target co-routine
		mov ebx, [CORS + 4]
		call dword resume
;     (*) calculate random angle ∆α       ; generate a random number in range [-60,60] degrees, with 16 bit resolution
		call get_random_delta_angle
		mov [delta_a], eax
;     (*) calculate random speed change ∆a    ; generate random number in range [-10,10], with 16 bit resolution
		call get_random_delta_speed
		mov [delta_s], eax
;     (*) calculate a new drone position:
		push edx
		call calc_new_pos
		add esp, 4
		jmp mayDestroy_loop

; (*) end while 	
;     (*) switch back to a scheduler co-routine by calling resume(scheduler)
    end_of_loop:
		mov ebx, [CORS]
		call dword resume
		jmp drone_co

;------------------------------------------------------------------------
calc_new_pos:

	push ebp
	mov ebp, esp
	pushad

	mov edx, dword [ebp+8]			; first arg pointer to curr drone data

; (*) calculate a new drone position as follows:
; 		(*) first move speed units at the direction defined by the current angle, wrapping around the torus if needed. 
; 		(*) then change the current angle to be α + ∆α, keeping the angle between [0, 360] by wraparound if needed
; 		(*) then change the current speed to be speed + ∆a, keeping the speed between [0, 100] by cutoff if needed

; c = speed
; a = c * sin(α)
; x2 = x1 + b
; b = c * cos(α)
; y2 = y1 + a

; (*) first move speed units at the direction defined by the current angle
	
	mov ebx, [edx + AOFF]
	push ebx
	call convert_degrees_to_radians			; eax = angle in radians
	add esp, 4
	mov [var1], eax

	ffree
	fld 	dword [var1]					; st(0) = angle in radians
	fsincos									; st(0) = cos(α), st(1) = sin(α)
	
	fld 	dword [edx + SOFF]				; st(0) = c, st(1) = cos(α), st(2) = sin(α)
	fmulp									; st(0) = c * cos(α) = ∆x, st(2) = sin(α)
	mov eax, [edx + SOFF]
	fstp dword [var2]
	fld dword [var2]
	mov eax, [var2]
	fld 	dword [edx + XOFF]				; st(0) = x1, st(1) = ∆x, st(2) = sin(α)
	faddp									; st(0) = x2 = x1 + ∆x, st(1) = sin(α)
	fstp 	dword [edx + XOFF]				; set new x pos; st(0) = sin(α)
	
	fld 	dword [edx + SOFF]				; st(0) = c, st(1) = sin(α)
	fmulp									; st(0) = c * sin(α) = ∆y

	fld 	dword [edx + YOFF]				; st(0) = y1, st(1) = ∆y
	faddp									; st(0) = y2 = y1 + ∆y
	fstp 	dword [edx + YOFF]				; set new y pos


; wrapping around the torus if needed
	; ffree
; wrap_x:
	ffree
	fld 	dword 	[edx + XOFF]			; st(0) = x (new)
	mov 	eax, 	[edx + XOFF]
	mov 	[var2], eax						; var2 = x
	mov 	dword 	[var1], 100				; var1 = 100 (int)
	fild 	dword 	[var1]					; st(0) = 100, st(1) = x 
	fcomip									; if (x <= 100)
	jae positive_x							; if x is less than 100, continue to check if it is positive

	; else, update x so it will stay inside the board
	fild 	dword [var1]					; st(0) = 100, st(1) = x
	fsubp									; st(0) = x - 100
	fstp 	dword [var2]					; var2 = x (updated)

	positive_x:
		ffree
		fld 	dword [var2]				; st(0) = x
		mov 	dword [var1], 0				; var1 = 0
		fild 	dword [var1]				; st(0) = 0, st(1) = x
		fcomip								; if (x >= 0)
		jnae set_new_x						; if x is in range, continue

		; else, update x so it will stay inside the board
		mov 	dword 	[var1], 100			; var1 = 100 (int)
		fild 	word 	[var1]				; st(0) = 100, st(1) = x
		faddp								; st(0) = x + 100
		fstp 	dword 	[var2]				; var2 = x (updated)

	set_new_x:
		mov eax, [var2]
		mov [edx + XOFF], eax
	; wrap_y:
		ffree
		fld 	dword 	[edx + YOFF]		; st(0) = y (new)
		mov 	eax, 	[edx + YOFF]
		mov 	[var2], eax					; var2 = y
		mov 	dword 	[var1], 100			; var1 = 100 (int)
		fild 	dword 	[var1]				; st(0) = 100, st(1) = y 
		fcomip								; if (y <= 100)
		jae positive_y						; if y is less than 100, continue to check if it is positive

		; else, update y so it will stay inside the board
		fild 	dword [var1]				; st(0) = 100, st(1) = y
		fsubp								; st(0) = y - 100
		fstp 	dword [var2]				; var2 = y (updated)

	positive_y:
		ffree
		fld 	dword [var2]				; st(0) = y
		mov 	dword [var1], 0				; var1 = 0
		fild 	dword [var1]				; st(0) = 0, st(1) = y
		fcomip								; if (y >= 0)
		jnae set_new_y						; if y is in range, continue

		; else, update y so it will stay inside the board
		mov 	dword [var1], 100			; var1 = 100 (int)
		fild 	dword [var1]				; st(0) = 100, st(1) = y
		faddp								; st(0) = y + 100
		fstp 	dword [var2]				; var2 = y (updated)

	set_new_y:
		mov 	eax, [var2]
		mov 	[edx + YOFF], eax

	; (*) then change the current angle to be α + ∆α
		mov 	eax, [edx + AOFF]			; eax = our angle in radians
		push 	eax
		call convert_radians_to_degrees
		add 	esp, 4						; eax = our angle in drgrees

		ffree
		fld 	dword [delta_a]				; st(0) = ∆α
		mov 	[var1], eax					; var1 = α (in degrees)
		fld 	dword [var1]				; st(0) = α, st(1) = ∆α
		faddp								; st(0) = α + ∆α
		fstp 	dword [delta_a]				; delta_a is now set to be (α + ∆α) - we use this variable for the updated angle, until it will be wrapped
		fld 	dword [delta_a]

	; wrap_α:
		mov 	dword [var1], 360			; var1 = 360 (degrees)
		fild 	dword [var1]				; st(0) = 360, st(1) = α + ∆α
		fcomip								; if (new_angle <= 360) (new_angle = α + ∆α)
		jae positive_a						; if true, continue to check if positive
		; else, sub 360 from new_angle
		fild 	dword [var1]				; st(0) = 360, st(1) = new_angle
		fsubp								; st(0) = new_angle - 360
		fstp 	dword [delta_a]				; delta_a = new_angle

	positive_a:
		ffree
		fld 	dword [delta_a]				; st(0) = new_angle
		mov 	dword [var1], 0				; var1 = 0
		fild 	dword [var1]				; st(0) = 0, st(1) = new_angle
		fcomip								; if (new_angle >= 0)
		jnae set_new_a						; if true, set new angle value
		; else, add 360 to new_angle
		mov 	dword [var1], 360				; var1 = 360
		fild 	dword [var1]					; st(0) = 360, st(1) = new_angle
		faddp								; st(0) = new_angle + 360
		fstp 	dword [delta_a]				; delta_a = new_angle

	set_new_a:
		push 	dword 			[delta_a]
		call 	convert_degrees_to_radians
		add 	esp, 			4
		mov 	[edx + AOFF], 	eax

; (*) then change the current speed to be speed + ∆a
		ffree
		; mov eax, [edx + SOFF]				; eax = our speed (float)

		fld 	dword [delta_s]				; st(0) = ∆s
		; mov [var1], eax					; var1 = speed (float)
		; fld dword [var1]					; st(0) = speed, st(1) = ∆a
		fld 	dword [edx + SOFF]			; st(0) = speed, st(1) = ∆a
		faddp								; st(0) = speed + ∆a
		fstp 	dword [delta_s]				; delta_s is now set to be (speed + ∆a) - we use this variable for the updated the speed, until it will be cutoff
		fld 	dword [delta_s]
	; cutoff_speed:
		mov 	dword [var1], 100			; var1 = 100 (int)
		fild 	dword [var1]				; st(0) = 100, st(1) = speed + ∆a
		fcomip								; if (new_speed <= 100) (new_speed = speed + ∆a)
		jae positive_s						; if true, continue to check if positive
		; else, new_speed = 100
		fstp 	dword [var2]				; var2 = new_speed : garbage
		fild 	dword [var1]				; st(0) = 100
		fstp 	dword [delta_s]				; delta_s = new_speed = 100

	positive_s:
		fld 	dword [delta_s]				; st(0) = new_speed
		mov 	dword [var1], 0				; var1 = 0
		fild 	dword [var1]				; st(0) = 0, st(1) = new_speed
		fcomip								; if (new_speed >= 0)
		jnae set_new_s						; if true, set new angle value
		; else, new_speed = 0
		fstp 	dword [var2]				; var2 = new_speed : garbage
		fild 	dword [var1]				; st(0) = 0
		fstp 	dword [delta_s]				; delta_s = new_speed = 0

	set_new_s:
		mov eax, [delta_s]
		mov [edx + SOFF], 	eax

	popad
	mov esp, ebp	
	pop ebp
	ret
;------------------------------------------------------------------------