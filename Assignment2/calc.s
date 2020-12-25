section	.rodata								; we define (global) read-only variables in .rodata section
; formats
	format_string: db "%s", 10, 0			; format string
	format_decimal: db "%d", 10, 0			; format decimal
	format_hexa: db "%02X", 10, 0			; format hexa

	format_hexa_no_leading_zero: db "%X", 0
	format_hexa_normal: db "%02X", 0

; prompts
	new_line: db 10, 0
	calc_prompt: db "calc: ", 0
	overflow_prompt: db "Error: Operand Stack Overflow", 10, 0 
	underflow_prompt: db "Error: Insufficient Number of Arguments on Stack", 10, 0
	init_default_prompt: db "Stack size was not mentioned\ illegal. Initializing to default size: 5", 10, 0

; debug msg
	debug_input_string: db "User request from myCalc: %s", 0
	debug_push_string: db "Done operating required operation. Value pushed is: ", 0
	debud_quit_prompt: db "Sorry to see you go... :(", 10, 0
	debud_quit_report: db "Number of operations you preformed: ", 0

section .data
	ret: dd 0
	op_counter: dd 0						; pointer to num of operation
	stack_counter: dd 0
	debug: db 0								; debug mode
	carry: db 0

section .bss								; we define (global) uninitialized variables in .bss section
	stack_pointer: resd 1
	stack_size: resd 1
	zero: resb 1
	input: resb 82  						; an array of chars where the input read is stored
	output: resb 256
	save_return_value: resd 1
	argA: resd 1
	argB: resd 1
	argC: resd 1
	to_free_one: resd 1
	to_free_two: resd 1

section .text
	align 16
  	global main
	extern printf
	extern fprintf 
	extern malloc 
	extern calloc 
	extern free 
	extern getchar
	extern stdin 
	extern fgets
	extern stderr 

;------------------------------------------------------------------------
%define DEAFULT_STACK_SIZE 5

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

%macro convert_hex_char_to_int 1
	mov byte dl, %1
	cmp dl, 'A'
	jl %%number	
	add dl, 10
	sub dl, 'A'
	jmp %%ret
	%%number:
		sub dl, '0'
	%%ret:
%endmacro

%macro get_new_link 0
	pushad
	push 5									;we need 5 bytes
	call malloc
	add esp, 4
	mov [save_return_value], eax
	popad
	mov eax, [save_return_value]
%endmacro

%macro my_push 1
	pushad

	;check if there a place
	mov ecx, [stack_size]
	mov ebx, [stack_counter]
	cmp ecx, ebx
	je %%cant_push
	
	;insert into the pointer
	mov edx, [stack_pointer]
	mov [edx], %1
	
	;increment pointer
	add edx, 4
	mov [stack_pointer], edx

	;increment counter
	inc ebx
	mov [stack_counter], ebx
	
	mov dword ecx, [debug]
	cmp ecx, 1
	jne %%ret
	print_prompt_if_debug debug_push_string
	push %1
	call print_list_if_debug
	add esp, 4
	print_prompt_if_debug new_line
	jmp %%ret

	%%cant_push:
		free_linked_list %1
		print_prompt overflow_prompt

	%%ret:
		popad
%endmacro

;this macro return ans in eax
%macro my_pop 0
	pushad

	;check if we can pop
	mov ebx, [stack_counter]
	cmp ebx, 0
	je stack_underflow
	
	;decrement pointer
	mov edx, [stack_pointer]
	sub edx, 4
	mov [stack_pointer], edx
	
	;taking value from the pointer
	mov eax ,[edx]
	mov [save_return_value], eax

	;decrement counter
	dec ebx
	mov [stack_counter], ebx

	popad
	mov eax, [save_return_value]
%endmacro

; increment by 1 the number of operation (success or not)
; and update stack pointer
; inc_stack_counter
%macro inc_op_counter 0
	push ebx
	mov ebx,[op_counter]
	inc ebx
	mov [op_counter],ebx
	pop ebx
%endmacro

%macro free_linked_list 1
	push ebx
	mov ebx, %1						; eax is curr node
	mov ebx, [ebx+1]				; ebx is next
	%%free_curr_cell_loop:
		push %1
		call free
		add esp, 4
		cmp ebx, 0
		je %%ret
		mov %1, ebx
		mov ebx, [ebx+1]				; ebx is next
		jmp %%free_curr_cell_loop
	%%ret:
	pop ebx
%endmacro

%macro	print_if_debug 2					; print out every number read from the user
	pushad
	mov dword ecx, [debug]
	cmp ecx, 1								; if debug mode is true: print input
	jne %%ret								; else continue
	push %1
	push %2
	push dword [stderr]
	call fprintf
	add esp, 12
	%%ret:
	popad
%endmacro

%macro	print_prompt_if_debug 1				; print out every number read from the user
	pushad
	mov dword ecx, [debug]
	cmp ecx, 1								
	jne %%ret								
	push %1
	push dword [stderr]
	call fprintf
	add esp, 8
	%%ret:
	popad
%endmacro

;------------------------------------------------------------------------
print_byte:
	push ebp
	mov ebp, esp	
	pushad

	mov ebx, dword [ebp+8]					; pointer to the node
	mov ecx, [ebx+1]						; pointer to next

	cmp ecx, 0								; case of end of linked list
	je .print_last_node

	push ecx
	call print_byte
	add esp, 4

	mov eax, 0
	mov al, [ebx]
	print eax, format_hexa_normal
	jmp .return

	.print_last_node:
		mov eax, 0
		mov al, [ebx]
		print eax, format_hexa_no_leading_zero
	.return:
		popad			
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
print_list_if_debug:
	push ebp
	mov ebp, esp	
	pushad

	mov ebx, dword [ebp+8]					; pointer to the node
	mov ecx, [ebx+1]						; pointer to next

	cmp ecx, 0								; case of end of linked list
	je .print_last_node

	push ecx
	call print_list_if_debug
	add esp, 4

	mov eax, 0
	mov al, [ebx]
	print_if_debug eax, format_hexa_normal
	jmp .return

	.print_last_node:
		mov eax, 0
		mov al, [ebx]
		print_if_debug eax, format_hexa_no_leading_zero
	.return:
		popad			
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
clear_leading_zero:
		push ebp
		mov ebp, esp	
		pushad

		mov byte [ret], 0						; "int ret" (flag)
		mov ebx, dword [ebp+8]					; pointer to the node
		mov ecx, [ebx+1]						; pointer to next

		cmp ecx, 0								; case of end of linked list
		jne .else
		cmp byte [ebx], 0						; check if curr->data == 0
		jne .flag_off
		mov byte [ret], 1								; we can free this link
		jmp .return

	.else:
		push ecx
		call clear_leading_zero
		add esp, 4
		mov [ret], eax

		cmp byte [ret], 0
		je .flag_off
		free_linked_list ecx
		mov dword [ebx+1], 0					; curr->next = 0
		cmp byte [ebx], 0						; check if curr->data == 0
		jne .flag_off
		mov byte [ret], 1
		jmp .return
		
		.flag_off:
			mov byte [ret], 0
		.return:
			popad
			mov eax, [ret]			
			mov esp, ebp	
			pop ebp
			ret
;------------------------------------------------------------------------
dup:
	push ebp
	mov ebp, esp	
	pushad
	mov eax, dword [ebp+8]

	mov dword [argA], eax
	mov dword [argC], 0
	mov ebx, 0						;ebx is a pointer where to put the next byte.
	mov edx, 0
	mov ecx, eax

	keep_duplicate:
		;enter the data of the current link to new link
		mov byte dl, [ecx]
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		mov dword ecx, [ecx+1]
		;eax - hold the new link, ecx - point the next input link
		;get the place where to put this link
		cmp ebx, 0
		jne append_in_list
		;it is the first link
		mov dword [argC], eax
		mov ebx, eax					;update ebx
		jmp check_for_more_links
	append_in_list:
		;ebx - keeps the address of the last link
		mov dword [ebx+1], eax
		mov dword ebx, [ebx+1]				;update ebx
	check_for_more_links:
		cmp ecx, 0
		je push_dup
		;else - there is more input in the next, remember: ecx - point the next input link
		jmp keep_duplicate
	push_dup:
		mov dword eax, [argA]
		my_push eax
		mov dword eax, [argC]
		my_push eax
		
		popad			
		mov esp, ebp	
		pop ebp
		ret
; -----------------------------------------------------------------------
num_of_hex_dig:
	push ebp
	mov ebp, esp	
	pushad
	mov eax, dword [ebp+8]

	mov dword [to_free_one], eax
	mov ebx, eax							; ebx is the pointer to linked list
	mov ecx, 0								; ecx is the counter

	mov eax, 0
	count_loop:
				
		add ecx, 2							; update pointer before inserting a digit

		mov byte al, [ebx]
		mov ebx, [ebx+1]					; update linked list pointer (to next)
		cmp ebx, 0							; case of end of linked list
		jne count_loop
		cmp eax, 15
		jg push_num_of_hexa_digits
		dec ecx

	;ebx - mask, ecx - length, edx - the specific byte
	push_num_of_hexa_digits:
		mov ebx, 0xff000000

	search_high_byte:
		mov edx, ecx
		and edx, ebx
		shr ebx, 8			;move the mask to the right
		cmp edx, 0
		je search_high_byte

		;else - edx hold the high byte
	rotate_right_first:
		push ecx
		mov ecx, 0xff
		mov eax, edx
		and eax, ecx
		cmp eax,0
		jne insert_first_byte
		shr edx,8
		jmp rotate_right

	insert_first_byte:
		get_new_link 		; the address of the link in eax
		mov byte [eax], dl
		mov dword [eax+1], 0
		my_push eax
		jmp get_next

	rotate_right:
		mov ecx, 0xff
		mov eax, edx
		and eax, ecx
		cmp eax,0
		jne insert_byte
		shr edx,8
		jmp rotate_right
	
	insert_byte:
		get_new_link 		; the address of the link in eax
		mov edx, eax
		my_pop				; the popped data in eax
		mov byte [edx], bl
		mov dword [edx+1], eax
		mov eax,edx
		my_push eax
		
		;push to stack
		
	;get the next byte from ecx
	get_next:
		pop ecx
		cmp ebx, 0
		je free_before_end_op
		mov edx, ecx
		and edx, ebx
		shr ebx, 8			;move the mask to the right
		jmp rotate_right
	
	free_before_end_op:
		mov dword eax, [to_free_one]
		free_linked_list eax

		popad			
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
add: 
	push ebp
	mov ebp, esp	
	pushad

	add_two_numbers:
		mov ecx, 0
		mov edx, 0
		mov eax, [argA]
		mov ebx, [argB]
		mov byte cl, [eax]
		mov byte dl, [ebx]
		;check for carry
		mov eax,0
		mov byte al,[carry]
		cmp al,1
		jne add_without_carry
		print 1, format_decimal
		stc						; set carry flag back.
		mov byte [carry],0
		jmp adding
	add_without_carry:
		clc						; reset carry
	adding:
		adc dl,cl		;the and in dl
		;update carry var
		jnc there_is_no_carry
		mov byte [carry], 1
		
	there_is_no_carry:
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		;check if argC is 0
		mov ecx, [argC]
		mov ebx, ecx
		cmp ecx,0
		jne insert_in_front_add
		;else - the first link
		mov [argC], eax		; argC contain the link list
		jmp check_if_there_more_add
		
	insert_in_front_add:
		mov ecx, ebx		; keep the last link
		mov ebx, [ebx+1]	; update ebx to see if there is another link
		cmp ebx, 0
		jne insert_in_front_add
		mov [ecx+1], eax	;change the link to look on eax now
		
	check_if_there_more_add:
		;check if there is next link
		mov eax,[argA]
		cmp dword [eax+1], 0
		je argA_is_done_add
		mov eax,[argB]
		cmp dword [eax+1], 0
		je argB_is_done_and_argA_not_add
		
		;keep argA and argB to look on the next link
		mov eax, [eax+1]	;eax was [argB], now he point the next link
		mov [argB], eax
		
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp add_two_numbers

	argB_is_done_and_argA_not_add:
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp add_one_number
	argA_is_done_add:
		mov eax,[argB]
		cmp dword [eax+1], 0
		je check_for_carry
		;else - there is still in argB
		mov eax, [argB]
		mov eax, [eax+1]
		mov [argA], eax
	
	add_one_number:
		mov edx, 0
		mov eax, [argA]
		mov byte dl, [eax]
		
		;check for carry
		mov eax,0
		mov byte al,[carry]
		cmp eax,1
		jne add_one_number_without_carry
		stc						; set carry flag back.
		mov byte [carry],0
		jmp adding_one_number
	add_one_number_without_carry:
		clc
	adding_one_number:
		adc dl,0			;calculate the carry if there is
		;update carry var
		jnc no_need_to_update_carry
		mov byte [carry], 1
	
	no_need_to_update_carry:
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		
		mov ecx, [argC]
		mov ebx, ecx
	get_the_last_link_add:
		mov ecx,ebx
		mov ebx, [ebx+1]	; update ebx to see if there is another link
		cmp ebx, 0
		jne get_the_last_link_add
		mov [ecx+1], eax	;change the link to look on eax now
		
		;check if there is next link
		mov eax,[argA]
		cmp dword [eax+1], 0
		je check_for_carry
		
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp add_one_number

	check_for_carry:
		;there is no more links, but can be more carry
		mov eax,0
		mov byte al,[carry]
		cmp eax,1
		jne push_argC_add
		mov byte [carry],0
		;else - there is carry and no more bytes to add
		get_new_link
		mov byte [eax], 1
		mov dword [eax+1], 0
		add eax,0					;clean carry flag

		mov ecx, [argC]
		mov ebx, ecx
		jmp get_the_last_link_add

	push_argC_add:
		mov eax,[argC]
		my_push eax
		mov dword eax, [to_free_one]
		free_linked_list eax
		mov dword eax, [to_free_two]
		free_linked_list eax

		popad			
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
and:
	push ebp
	mov ebp, esp	
	pushad

	and_two_numbers:
		mov ecx, 0
		mov edx, 0
		mov eax, [argA]
		mov ebx, [argB]
		mov byte cl, [eax]
		mov byte dl, [ebx]
		and dl,cl		;the and in dl
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		;check if argC is 0
		mov ecx, [argC]
		mov ebx, ecx
		cmp ecx,0
		jne insert_in_front_and
		;else - the first link
		mov [argC], eax		; argC contain the link list
		jmp check_for_next_and
		
	insert_in_front_and:
		mov ecx, ebx		; keep the last link
		mov ebx, [ebx+1]	; update ebx to see if there is another link
		cmp ebx, 0
		jne insert_in_front_and
		mov [ecx+1], eax	;change the link to look on eax now
		
	check_for_next_and:
		;check if there is next link
		mov eax,[argA]
		cmp dword [eax+1], 0
		je push_argC_and
		mov eax,[argB]
		cmp dword [eax+1], 0
		je push_argC_and
		
		;keep argA and argB to look on the next link
		mov eax, [eax+1]	;eax was [argB], now he point the next link
		mov [argB], eax
		
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp and_two_numbers
	
	push_argC_and:
		mov eax, [argC]
		push eax
		call clear_leading_zero
		add esp, 4
		
		mov eax, [argC]
		my_push eax
		mov dword eax, [to_free_one]
		free_linked_list eax
		mov dword eax, [to_free_two]
		free_linked_list eax

		popad			
		mov esp, ebp	
		pop ebp
		ret
;------------------------------------------------------------------------
or:
	push ebp
	mov ebp, esp	
	pushad
	or_two_numbers:
		mov ecx, 0
		mov edx, 0
		mov eax, [argA]
		mov ebx, [argB]
		mov byte cl, [eax]
		mov byte dl, [ebx]
		or dl,cl		;the and in dl
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		;check if argC is 0
		mov ecx, [argC]
		mov ebx, ecx
		cmp ecx,0
		jne insert_in_front_or
		;else - the first link
		mov [argC], eax		; argC contain the link list
		jmp check_if_more
		
	insert_in_front_or:
		mov ecx, ebx		; keep the last link
		mov ebx, [ebx+1]	; update ebx to see if there is another link
		cmp ebx, 0
		jne insert_in_front_or
		mov [ecx+1], eax	;change the link to look on eax now
		
	check_if_more:
		;check if there is next link
		mov eax,[argA]
		cmp dword [eax+1], 0
		je argA_is_done
		mov eax,[argB]
		cmp dword [eax+1], 0
		je argB_is_done_and_argA_not
		
		;keep argA and argB to look on the next link
		mov eax, [eax+1]	;eax was [argB], now he point the next link
		mov [argB], eax
		
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp or_two_numbers

	argB_is_done_and_argA_not:
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp or_one_number
	argA_is_done:
		mov eax,[argB]
		cmp dword [eax+1], 0
		je push_argC
		;else - there is still in argB
		mov eax, [argB]
		mov eax, [eax+1]
		mov [argA], eax
	
	or_one_number:
		mov edx, 0
		mov eax, [argA]
		mov byte dl, [eax]
		get_new_link
		mov byte [eax], dl
		mov dword [eax+1], 0
		
		mov ecx, [argC]
		mov ebx, ecx
	get_the_last_link:
		mov ecx,ebx
		mov ebx, [ebx+1]	; update ebx to see if there is another link
		cmp ebx, 0
		jne get_the_last_link
		mov [ecx+1], eax	;change the link to look on eax now
		
		;check if there is next link
		mov eax,[argA]
		cmp dword [eax+1], 0
		je push_argC
		
		mov eax, [argA]
		mov eax, [eax+1]
		mov [argA], eax
		jmp or_one_number

	push_argC:
		mov eax,[argC]
		my_push eax
		mov dword eax, [to_free_one]
		free_linked_list eax
		mov dword eax, [to_free_two]
		free_linked_list eax
	
	popad			
	mov esp, ebp	
	pop ebp
	ret
;------------------------------------------------------------------------
bye:
	push ebp
	mov ebp, esp	
	pushad

	print_prompt_if_debug debud_quit_prompt
	print_prompt_if_debug debud_quit_report
	print dword [op_counter], format_hexa_no_leading_zero
	print_prompt new_line

	free_stack_cells_loop:
		mov ebx, [stack_counter]
		cmp ebx, 0
		je free_stack						; elements in the stack are freed
		; else, we want to free the linked list in curr cell
		my_pop
		
	mov ebx, eax						; eax is curr node
	mov ebx, [ebx+1]					; ebx is next
	free_curr_cell_loop:
		push eax
		call free
		add esp, 4
		cmp ebx, 0
		je free_stack_cells_loop
		mov eax, ebx
		mov ebx, [ebx+1]				; ebx is next
		jmp free_curr_cell_loop

	free_stack:
		push dword [stack_pointer]
		call free
		add esp, 4
	
	popad			
	mov esp, ebp	
	pop ebp
	ret
;------------------------------------------------------------------------
insert_number:	
	push ebp
	mov ebp, esp	
	pushad
											; else, it is a number
	mov ecx, 0								; num_length (accumolator)
	
	count_input_loop:
		cmp byte [input+ecx], 10
		je end_count
		inc ecx
		jmp count_input_loop
		
	end_count:
		mov edx, input
		and ecx, 1
		cmp ecx, 0
		je even_len
		
		; else, odd
		mov edx, zero
		
	even_len:
		mov ecx, edx

	mov eax, 0 ; next
	input_number_loop:
		convert_hex_char_to_int [ecx]
		
		mov ebx, edx
		shl ebx, 4
		inc ecx

		convert_hex_char_to_int [ecx]

		add ebx, edx
		inc ecx

		mov edx, eax
		get_new_link 					; the address of the link in eax
		mov byte [eax], bl
		mov dword [eax+1], edx

		cmp byte [ecx], 10

		jne input_number_loop

		push eax
		call clear_leading_zero
		pop eax
		my_push eax
	
	popad			
	mov esp, ebp	
	pop ebp
	ret
;------------------------------------------------------------------------

main:
	push ebp
	mov ebp, esp
	mov ecx, dword [ebp+8]						; get argc
	add esp, 4
	cmp ecx, 1
	jle init_stack_with_default_size

	parse_cmd_args:
		mov eax, dword [ebp+12]					; get **argv
		mov ebx, [eax+4]						; get argv[1]
		cmp byte [ebx], '-'						; check if argv[1] is "-d"
		jne three_args
		inc ebx
		cmp byte [ebx], 'd'
		jne three_args
		mov byte [debug], 1						; debug mode is set to true

	three_args:
		; we will check for another argument
		cmp ecx, 3
		jne check_first_arg
		
		mov edx, [eax+8]						; get argv[2]
		cmp byte [edx], '-'						; check if argv[2] is "-d"
		jne before_convert
		inc edx
		cmp byte [edx], 'd'
		jne before_convert
		mov byte [debug], 1						; debug mode is set to true
		jmp end_of_parse

	check_first_arg:
		cmp byte [debug], 1
		je init_stack_with_default_size
		jmp end_of_parse

	before_convert:
		; else, it is the stack size
		mov ebx, edx
	end_of_parse:
		mov ecx, 0								; the index
		mov eax, 0								; the result
		mov edx, 0								; init edx

	hextoi_loop:	
		mov dl, byte [ebx+ecx]
		cmp dl, 0
		je init_stack
		convert_hex_char_to_int [ebx+ecx]

		shl eax, 4
		add al, dl
		inc ecx
		jmp hextoi_loop

	init_stack_with_default_size:
		print_prompt_if_debug init_default_prompt
		mov eax, DEAFULT_STACK_SIZE
	init_stack:
		; check validity of stack size
		cmp eax, 2
		jle init_stack_with_default_size
		mov [stack_size], eax
		shl eax, 2								; multiply by 4 (each entry in the stack is 4 bytes)
		push eax
		call malloc
		add esp, 4
		mov [stack_pointer], eax

		mov byte [zero], '0'

;------------------------------------------------------------------------
myCalc:
	print_prompt calc_prompt
	
	push dword [stdin]
	push 80
	push dword input
	call fgets
	add esp, 12	

check_command:
	cmp byte [input], 'q'
	je quit
	print_if_debug dword input, debug_input_string	
	cmp byte [input], '+'
	je unsigned_addition
	cmp byte [input], 'p'
	je pop_and_print
	cmp byte [input], 'd'
	je duplicate
	cmp byte [input], '&'
	je bitwise_and
	cmp byte [input], '|'
	je bitwise_or
	cmp byte [input], 'n'
	je number_of_hexadecimal_digits
	cmp byte [input], 10
	je myCalc
	jmp is_number

is_number:
	call insert_number
	jmp myCalc

stack_underflow:
	popad
	print_prompt underflow_prompt
	jmp myCalc

quit:
	call bye
	ret

unsigned_addition:
	inc_op_counter
	mov dword [argC],0

	mov eax, [stack_counter]
	cmp eax, 2
	jge start_add
	print_prompt underflow_prompt
	jmp myCalc

	start_add:
		my_pop
		mov [to_free_one], eax
		mov [argA], eax
		my_pop
		mov [to_free_two], eax
		mov [argB], eax

	call add

	jmp myCalc

pop_and_print:
	inc_op_counter
	my_pop
	mov dword [to_free_one], eax

	push eax
	call print_byte
	add esp, 4
	print_prompt new_line
	
	mov dword eax, [to_free_one]
	free_linked_list eax
	jmp myCalc
	
duplicate:
	inc_op_counter
	my_pop
	push eax
	call dup
	add esp, 4
	jmp myCalc
	
bitwise_and:
	inc_op_counter
	mov dword [argC],0

	mov eax, [stack_counter]
	cmp eax, 2
	jge start_and
	pushad
	jmp stack_underflow

	start_and:
		my_pop
		mov [to_free_one], eax
		mov [argA], eax
		my_pop
		mov [to_free_two], eax
		mov [argB], eax

	call and

	jmp myCalc

bitwise_or:
	inc_op_counter
	mov dword [argC],0

	mov eax, [stack_counter]
	cmp eax, 2
	jge start_or
	pushad
	jmp stack_underflow

	start_or:
		my_pop
		mov [to_free_one], eax
		mov [argA], eax
		my_pop
		mov [to_free_two], eax
		mov [argB], eax
	
	call or

	jmp myCalc

number_of_hexadecimal_digits:
	inc_op_counter
	my_pop
	push eax
	call num_of_hex_dig
	add esp, 4
	jmp myCalc
;--------------------------------YAY----------------------------------------