; Comments start with a semicolon!
BITS 64 ; 64 bits.
CPU X64 ; Target the x86_64 family of CPUs.

%define SYSCALL_EXIT 60
%define SYSCALL_WRITE 1
%define STDOUT 1

section .text
global _start
_start:
  call print_hello 
  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall

print_hello:
  push rbp ; Save rbp on the stack to be able to restore it at the end of the function.
  mov rbp, rsp ; Set rbp to rsp

  sub rsp, 16 ; Reserve 16 bytes of space on the stack. (multipe of 16)
  mov BYTE [rsp + 0], 'h' ; Set each byte on the stack to a string character.
  mov BYTE [rsp + 1], 'e'
  mov BYTE [rsp + 2], 'l'
  mov BYTE [rsp + 3], 'l'
  mov BYTE [rsp + 4], 'o'

  ; Make the write syscall
  mov rax, SYSCALL_WRITE
  mov rdi, STDOUT ; Write to stdout.
  lea rsi, [rsp] ; Address on the stack of the string.
  mov rdx, 5 ; Pass the length of the string which is 5.
  syscall

  call print_world

  add rsp, 16 ; Restore the stack to its original value.

  pop rbp ; Restore rbp
  ret

print_world:
  push rbp
  mov rbp, rsp

  sub rsp, 16
  mov BYTE [rsp + 0], ' '
  mov BYTE [rsp + 1], 'w'
  mov BYTE [rsp + 2], 'o'
  mov BYTE [rsp + 3], 'r'
  mov BYTE [rsp + 4], 'l'
  mov BYTE [rsp + 5], 'd'

  mov rax, SYSCALL_WRITE
  mov rdi, STDOUT
  lea rsi, [rsp]
  mov rdx, 6
  syscall

  add rsp, 16

  pop rbp
  ret