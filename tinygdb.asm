; ╺┳╸╻┏┓╻╻ ╻┏━╸╺┳┓┏┓
;  ┃ ┃┃┗┫┗┳┛┃╺┓ ┃┃┣┻┓
;  ╹ ╹╹ ╹ ╹ ┗━┛╺┻┛┗━┛

; lots of thanks to blackle for its work on x86_64 minification
; much of the base code was taken from its `ultraviolet` repository

; ┏┓ ┏━┓╻╻  ┏━╸┏━┓┏━┓╻  ┏━┓╺┳╸┏━╸   ┏━┓┏┓╻╺┳┓   ┏┳┓┏━┓┏━╸┏━┓┏━┓┏━┓
; ┣┻┓┃ ┃┃┃  ┣╸ ┣┳┛┣━┛┃  ┣━┫ ┃ ┣╸    ┣━┫┃┗┫ ┃┃   ┃┃┃┣━┫┃  ┣┳┛┃ ┃┗━┓
; ┗━┛┗━┛╹┗━╸┗━╸╹┗╸╹  ┗━╸╹ ╹ ╹ ┗━╸   ╹ ╹╹ ╹╺┻┛   ╹ ╹╹ ╹┗━╸╹┗╸┗━┛┗━┛

BITS 64

; syscall number definitions
%include "syscalls.asm"

;this is a hack that's 2 bytes smaller than mov!
%macro minimov 2
    push %2
    pop %1
%endmacro

; ┏━╸╻  ┏━╸   ╻ ╻┏━╸┏━┓╺┳┓┏━╸┏━┓
; ┣╸ ┃  ┣╸    ┣━┫┣╸ ┣━┫ ┃┃┣╸ ┣┳┛
; ┗━╸┗━╸╹     ╹ ╹┗━╸╹ ╹╺┻┛┗━╸╹┗╸

ehdr: ; Elf64_Ehdr

e_ident:
    db 0x7F, "ELF", 2, 1, 1, 0

e_padding:
    ; not for this syscall, for later
    push 8 ; hex counter
    push sys_execve

    mov al, sys_fork ; regular mov with an 8-bit register saves on bytes
    jmp p_flags

e_type:
    dw 2
e_machine:
    dw 0x3e
e_version:
    dd 1
e_entry:
    dq e_padding
e_phoff:
    dq phdr - $$
e_shoff:
    dq 0
e_flags:
    dd 0
e_ehsize:
    dw ehdrsize
e_phentsize:
    dw phdrsize

; the program header starts inside of the elf header
; shamelessly adapted from the 32-bit version at
; http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html

ehdrsize equ $ - ehdr

; ┏━┓┏━┓┏━┓┏━╸┏━┓┏━┓┏┳┓   ╻ ╻┏━╸┏━┓╺┳┓┏━╸┏━┓
; ┣━┛┣┳┛┃ ┃┃╺┓┣┳┛┣━┫┃┃┃   ┣━┫┣╸ ┣━┫ ┃┃┣╸ ┣┳┛
; ╹  ╹┗╸┗━┛┗━┛╹┗╸╹ ╹╹ ╹   ╹ ╹┗━╸╹ ╹╺┻┛┗━╸╹┗╸

phdr: ; Elf64_Phdr

p_type:
    dd 1

p_flags:
    ; p_flags is supposed to be 0x0f, and syscall is 0x0f05;
    ; the kernel only looks at the bottom byte, so i can put code here!
    syscall
    jmp p_paddr

p_offset:
    dq 0
p_vaddr:
    dq $$

p_paddr: ; apparently p_paddr can be nonsense?
    ; swap fork return value for sys_execve we stored in r15 before
    mov r15, rax
    pop rax ; remember that value we pushed at the very beginning?

    pop rcx ; also pushed at the beginning
    pop rbx ; argc

    jmp _start

p_filesz:
    dq filesize
p_memsz:
    dq filesize
p_align:
    dq 0x10

phdrsize equ $ - phdr

; ╻ ╻┏━┓╻  ╻ ╻   ┏━┓╻ ╻╻╺┳╸   ╺┳╸╻ ╻┏━╸┏━┓┏━╸╻┏━┓   ┏━┓┏━╸╺┳╸╻ ╻┏━┓╻  ╻  ╻ ╻   ┏━╸┏━┓╺┳┓┏━╸
; ┣━┫┃ ┃┃  ┗┳┛   ┗━┓┣━┫┃ ┃     ┃ ┣━┫┣╸ ┣┳┛┣╸  ┗━┓   ┣━┫┃   ┃ ┃ ┃┣━┫┃  ┃  ┗┳┛   ┃  ┃ ┃ ┃┃┣╸
; ╹ ╹┗━┛┗━╸ ╹    ┗━┛╹ ╹╹ ╹     ╹ ╹ ╹┗━╸╹┗╸┗━╸ ┗━┛   ╹ ╹┗━╸ ╹ ┗━┛╹ ╹┗━╸┗━╸ ╹    ┗━╸┗━┛╺┻┛┗━╸

_start:
    lea rdi, [gdb_argv.3 + 2] ; load target address for hex conversion
    ; convert the pid to hex and store it in gdb_argv
    .convert_hex:
        rol r15d, 4 ; roll over to next nybble in pid of child (32bit)
        mov dl, r15b ; mov byte
        and dl, 0x0f ; isolate the nybble
        add dl, "0" ; convert to ascii
        cmp dl, "9" ; compare to ascii '9'
        jna .move_hex ; if not above '9', skip to moving the value into memory
        add dl, "a" - "9" - 1 ; add to get to a-f
    .move_hex:
        mov byte[rdi], dl
        inc rdi
        dec cl
        jnz .convert_hex ; if cl isn't 0 do it again

    shl rbx, 3 ; multiply by 8 for qword
    lea rsi, [rsp + 8] ; base pointer to argv of current process starting at argv[1]
    minimov rdi, qword [rsi] ; argv[0] for child
    minimov rdx, rsi ; copy rsi so we can add to it to get the env pointer
    add rdx, rbx ; env pointer!

    ; check if we're running in the child process or not
    cmp r15, 0
    jz child

parent:
    ; actually execve
    minimov rdi, gdb_argv.0
    minimov rsi, gdb_argv
    ; rdx already has env
    syscall

child:
    ; save registers
    push rax
    push rdi
    push rsi
    push rdx

    mov al, sys_getpid
    syscall

    ; swap sys_kill with the pid
    minimov rdi, sys_kill
    xchg rax, rdi
    minimov rsi, 19 ; sigstop
    syscall

    ; restore registers
    pop rdx
    pop rsi
    pop rdi
    pop rax
    syscall ; exec tiny program

; ┏━┓╺┳╸┏━┓╻┏┓╻┏━╸┏━┓
; ┗━┓ ┃ ┣┳┛┃┃┗┫┃╺┓┗━┓
; ┗━┛ ╹ ╹┗╸╹╹ ╹┗━┛┗━┛

gdb_argv:
    dq .0, .1, .2, .3, .4, .5, .6, .7, 0

    .0: db "/usr/bin/env", 0
    .1: db "gdb", 0
    .2: db "-p", 0
    .3: db "0x00000000", 0
    .4: db "-ex", 0
    .5: db "catch exec", 0
    .6: db "-ex", 0
    .7: db "queue-signal SIGCONT", 0

filesize equ $ - $$
