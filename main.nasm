; Comments start with a semicolon!
BITS 64 ; 64 bits.
CPU X64 ; Target the x86_64 family of CPUs.

%define SYSCALL_EXIT 60
%define SYSCALL_WRITE 1
%define STDOUT 1
%define AF_UNIX 1
%define SOCK_STREAM 1
%define SYSCALL_SOCKET 41
%define SYSCALL_CONNECT 42

section .rodata
  sun_path: db "/tmp/.X11-unix/X0", 0
  static sun_path:data

section .text
global _start
_start:
  call print_hello 
  call x11_connect_to_server

  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall

die:
  mov rax, SYSCALL_EXIT
  mov rdi, 1
  syscall  

x11_connect_to_server:
static x11_connect_to_server:function
  push rbp
  mov rbp, rsp

; open a unix socket.
  mov rax, SYSCALL_SOCKET
  mov rdi, AF_UNIX ; Unix socket.
  mov rsi, SOCK_STREAM ; Stream oriented.
  mov rdx, 0 ; automatic protocol.
  syscall

  cmp rax, 0
  jle die

  mov rdi, rax ; Store socket fd in `rdi` for the remainder of the function.

  sub rsp, 112 ; Store struct sockaddr_un on the stack.

  mov WORD [rsp], AF_UNIX ; Set sockaddr_un.sun_family to AF_UNIX
  ; Fill sockaddr_un.sun_path with: "/tmp/.X11-unix/X0".
  lea rsi, sun_path
  mov r12, rdi ; Save the socket file descriptor in `rdi` in `r12`.
  lea rdi, [rsp + 2]
  cld ; Move forward
  mov ecx, 19 ; Length is 19 with the null terminator.
  rep movsb ; Copy.

  ; Connect to the server: connect(2).
  mov rax, SYSCALL_CONNECT
  mov rdi, r12
  lea rsi, [rsp]
  %define SIZEOF_SOCKADDR_UN 2+108
  mov rdx, SIZEOF_SOCKADDR_UN
  syscall

  cmp rax, 0
  jne die

  mov rax, rdi ; Return the socket fd.

  add rsp, 112
  pop rbp
  ret

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