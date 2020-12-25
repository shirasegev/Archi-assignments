section	.rodata						; we define (global) read-only variables in .rodata section
	format_string: db "%s", 10, 0	; format string

section .bss						; we define (global) uninitialized variables in .bss section
	an: resb 12						; enough to store integer in [-2,147,483,648 (-2^31) : 2,147,483,647 (2^31-1)]
	array: resb 9					; for 8 hexa digits and an null terminating character

section .text
	global convertor
	extern printf

convertor:
	push ebp
	mov ebp, esp	
	pushad			

	mov ecx, dword [ebp+8]			; get function argument (pointer to string)

	; your code comes here...
	mov eax, 0						; decimal value of user's input
	mov ebx, 0						; ebx is used to store the current character. initialized to 0
atoi:
	; end of loop conditions (0 or \n)
	mov bl, [ecx]
	cmp bl, 10
	je continue
	cmp bl, 0
	je continue

	; the loop
	imul eax, 10
	sub bl, '0'
	add eax, ebx
	inc ecx
	jmp atoi
	
continue:
	mov edx, array					; edx is the pointer to the last place we entred a value
	add edx, 8
	mov byte [edx], 0				; add a null termination at the end

	; handle special case of zero
	cmp eax, 0
	jne itohex

	; in case the input was zero
	dec edx							
	mov byte [edx], '0'
	jmp print

itohex:
	mov ebx, eax
	and ebx, 0x0f					; isolate the last 4 bits using mask
	cmp bl, 9
	jle num

	; else, it is a letter represantation (A-F in hexa)
	sub bl, 10
	add bl, 'A'
	jmp insert

num:
	add bl, '0'

insert:
	dec edx
	mov byte [edx], bl

	shr eax, 4						; go to the next digit
	cmp eax, 0
	jne itohex						; continue the loop if num is not zero

print:
	mov ecx, 0

move_before_print:
	mov byte al, [edx]
	mov byte [an+ecx], al
	inc edx
	inc ecx
	cmp al, 0
	jnz move_before_print

	push an							; call printf with 2 arguments -  
	push format_string				; pointer to str and pointer to format string
	call printf
	add esp, 8						; clean up stack after call

	popad			
	mov esp, ebp	
	pop ebp
	ret