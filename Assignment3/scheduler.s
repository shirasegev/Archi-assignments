section	.rodata								; we define (global) read-only variables in .rodata section
; formats
	format_string: db "%s", 10, 0			; format string
	format_decimal: db "%d", 10, 0			; format decimal
	format_hexa: db "0x%02X", 10, 0			; format hexa
	format_float: db "%.2f", 0 			    ; format float. 2 digits after the decimal point.
; prompts
	new_line: db 10, 0
    comma: db ",", 0
	the_winner_is: db "The Winner is drone: %d", 10, 0
	name: db "scheduler i=%d", 10, 0
	format_looser: db "looser is %d", 10, 0
	format_M: db "with M=%d", 10, 0

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

	index:		dd 		0					; index of current round
section .bss
	M: 				resd 1					; The lowest number of targets destroyed, between all of the active drones
	looser: 		resd 1					; Id of the drone which destroyed least targets
	winner: 		resd 1					; Id of the winner drone

section .text
	global scheduler_co
	extern resume
	extern do_resume

	extern co_scheduler_func
	extern co_target_func
	extern co_printer_func

    extern printf
    extern Nval
	extern Rval
	extern Kval
	extern angle
	extern Dval
	extern seed
	extern co_drones_stack
	extern co_drones_array
    ; extern active_drones
	extern curr_drone
	extern quit
	extern finish_main

	extern CORS

	extern CURR
	extern spmain
	extern co_scheduler
	extern drones_array
	extern co_drones_array
	extern co_target
	extern targetX
	extern targetY
	extern co_printer

;------------------------------------------------------------------------
%macro print_prompt 1
	pushad
	push %1
	call printf
	add esp, 4
	popad
%endmacro

; %macro	next_id 0					; get nextprint edx, format_decimal drone id in round-robin
; 	pushad
; 	mov eax, [Nval]					; eax = N
; 	dec eax							; eax = N-1
; 	mov ebx,[curr_drone]			; ebx = curr_drone
; 	cmp ebx, eax					; check if curr_drone = N-1
; 	je %%reset						; yes-> id=0
; 	; no-> id++
; 	inc ebx
; 	mov [curr_drone],ebx
; 	jmp %%cont
	
; 	%%reset:
; 		mov dword [curr_drone],0print edx, format_decimal
; 		jmp %%.cont
	
; 	%%cont:
; 		popad
; %endmacro

%macro print 2
	pushad
	push %1
	push %2
	call printf
	add esp, 8
	popad
%endmacro
;------------------------------------------------------------------------
; The loop in the function of a scheduler co-routine is as follows:
scheduler_co:
	; @TODO: delete this print
	; mov ebx, [CORS + 8]
	; call dword resume

	; (*) start from i=0
	mov dword [index], 0
	function_loop:
		mov eax, [index]
		; print eax, name
	; (*)if drone i%N is active
	mov eax, [index]					; divisend low half. eax = i
	mov edx, 0							; dividend high half = 0. prefer xor edx,edx
	mov ebx, [Nval]						; divisor can be any register or memory
	div ebx								; EDX = i%N - remainder
	mov [curr_drone], edx
	mov eax, edx
	mov ecx, DROSZ
	mul ecx								; eax = i*DROSZ
	mov ebx, [co_drones_array]
	add ebx, eax
	
	cmp byte [ebx+ACTOFF], 0	; check if the i'th droen is active
	je not_an_active_drone
		; (*) switch to the i’s drone co-routine
		call resume
		
	not_an_active_drone:
	; (*) if i%K == 0 //time to print the game board
	mov eax, [index]					; dividend low half
	mov edx, 0							; dividend high half = 0. prefer xor edx,edx
	mov ebx, [Kval]						; divisor can be any register or memory
	div ebx								; EDX = i%K remainder
	cmp edx, 0							; check if it's time to print the game board
	jne check_R
		; (*) switch to the printer co-routine
		mov ebx, [CORS + 8]
		call resume
	
	; (*) if (i/N)%R == 0 && i>0 && (i%N) == 0 //R rounds have passed
	check_R:
		cmp dword [index], 0
		jle check_one_left

		mov eax, [index]					; dividend low half
		mov edx, 0							; dividend high half = 0. prefer xor edx,edx
		mov ebx, [Nval]						; divisor can be any register or memory
		div ebx								; eax = (i/N) - quotient, edx = (i%N) - remainder
		cmp edx, 0
		jne check_one_left

		; eax is still (i/N)
		mov edx, 0							; dividend high half = 0. prefer xor edx,edx
		mov ebx, [Rval]						; divisor can be any register or memory
		div ebx								; EDX = (i/N)%R - remainder
		cmp edx, 0							; check if R rounds have passed
		jne check_one_left
		
		; (*) find M - the lowest number of targets destroyed, between all of the active drones
		mov ecx, [Nval]
		mov edx, [co_drones_array]			; edx is the pointer to the begining of the drones_array

		mov dword [M], 0x7fffffff

		find_M_loop:
			cmp byte [edx + ACTOFF], 1
			jne next
			mov ebx, [edx + NOFF]
			cmp dword ebx, [M]
			jge next
			mov [M], ebx
			mov ebx, [edx + DIDOFF]
			mov [looser], ebx

		next:
			add edx, DROSZ
			loop find_M_loop, ecx


		; (*) "turn off" one of the drones that destroyed only M targets.
		; print dword [looser], format_looser
		; print dword [M], format_M

		mov ebx, [looser]
		mov eax, DROSZ
		mul ebx					; eax = looserIndex * DROSZ
		mov ebx, [co_drones_array]
		add ebx, eax
		mov byte [ebx + ACTOFF], 0

	check_one_left:
	; (*) i++
		mov eax, [index]
		inc eax
		mov [index], eax

	; (*) if only one active drone is left
		mov edx, 0 			; edx is a counter of activate drones
		mov eax, 0
		mov ecx, [Nval]
		mov ebx, [co_drones_array]
		one_left_loop:
			cmp byte [ebx + ACTOFF], 0
			je dont_increment
			mov [winner], eax
			inc edx
		dont_increment:
			add ebx, DROSZ
			inc eax
			loop one_left_loop, ecx

		cmp edx, 1
		je end
		
		jmp function_loop

	end:
		; (*)print The Winner is drone: <id of the drone>
		mov eax, [winner]
		print eax, the_winner_is
		; (*) stop the game (return to main() function or exit)
		jmp finish_main
			
; A scheduler co-routine MUST be exclusively written in a separate file,
; the actual control transfer (context switch) should be done with the resume mechanism.
; Hence, label resume would be declared as extern to the scheduler,
; and register ebx would be used to transfer control.
