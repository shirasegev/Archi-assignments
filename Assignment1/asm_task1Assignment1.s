section	.rodata						; we define (global) read-only variables in .rodata section
	format_string: db "%d", 10, 0	; format string

section .text
	global assFunc
	extern c_checkValidity
	extern printf

assFunc:
	push ebp
	mov ebp, esp	
	pushad

	mov ebx, [ebp+8] 				; get first argument - x
	mov ecx, [ebp+12]				; get second argument - y

	; Call checkValidity
	push ecx 						; push the second argument - y
	push ebx 						; push the first argument - x
	call c_checkValidity 			; call the function
	add esp, 8 						; remove the arguments from the stack

	cmp eax, 0 						; return value is in eax
	jz sum_numbers 					; if 1, goto sum

	; else - sub numbers
	sub ebx, ecx
	jmp print

sum_numbers:
	add ebx, ecx

print:
	push ebx
	push format_string	            ; pointer to str and pointer to format string
	call printf
	add esp, 8		                ; clean up stack after call

	popad			
	mov esp, ebp	
	pop ebp
	ret