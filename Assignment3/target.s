section .data
    DROSZ		equ		37					; Size of one drone struct

section .text
    global target_co

    extern co_scheduler_func
    extern CORS
    extern resume
    extern createTarget
    extern curr_drone
    extern co_drones_array
;------------------------------------------------------------------------

; The function of a target co-routine is as follows:
target_co:
    ; (*) call createTarget() function to create a new target with randon coordinates on the game board
    call createTarget
    ; (*) switch to a scheduler co-routine by calling resume(scheduler) function
    mov eax, [curr_drone]			; eax = i
    mov ebx, DROSZ					; ebx = DROSZ
    mul ebx							; eax = i * DROSZ
    mov ebx, [co_drones_array]		; ebx = addressOf(drones)
    add ebx, eax					; ebx = addressOf(drones[i])
    call dword resume
    jmp target_co