; Comments start with a semicolon!
BITS 64 ; 64 bits.
CPU X64 ; Target the x86_64 family of CPUs.

%define SYSCALL_EXIT 60

section .text
global _start
_start:
  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall