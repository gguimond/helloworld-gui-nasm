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
%define SYSCALL_WRITE 1
%define SYSCALL_READ 0

section .data
  id: dd 0
  static id:data

  id_base: dd 0
  static id_base:data

  id_mask: dd 0
  static id_mask:data

  root_visual_id: dd 0
  static root_visual_id:data

section .rodata
  sun_path: db "/tmp/.X11-unix/X0", 0
  static sun_path:data

section .text
global _start
_start:
  call print_hello 
  call x11_connect_to_server
  call x11_send_handshake

  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall

die:
  mov rax, SYSCALL_EXIT
  mov rdi, 1
  syscall  

; Send the handshake to the X11 server and read the returned system information.
; @param rdi The socket file descriptor
; @returns The window root id (uint32_t) in rax.
x11_send_handshake:
static x11_send_handshake:function
  push rbp
  mov rbp, rsp

  sub rsp, 1<<15
  mov BYTE [rsp + 0], 'l' ; Set order to 'l'.
  mov WORD [rsp + 2], 11 ; Set major version to 11.

  ; Send the handshake to the server: write(2).
  mov rax, SYSCALL_WRITE
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, 12*8
  syscall

  cmp rax, 12*8 ; Check that all bytes were written.
  jnz die

  ; Read the server response: read(2).
  ; Use the stack for the read buffer.
  ; The X11 server first replies with 8 bytes. Once these are read, it replies with a much bigger message.
  mov rax, SYSCALL_READ
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, 8
  syscall

  cmp rax, 8 ; Check that the server replied with 8 bytes.
  jnz die

  cmp BYTE [rsp], 1 ; Check that the server sent 'success' (first byte is 1).
  jnz die

   ; Read the rest of the server response: read(2).
  ; Use the stack for the read buffer.
  mov rax, SYSCALL_READ
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, 1<<15
  syscall

  cmp rax, 0 ; Check that the server replied with something.
  jle die

  ; Set id_base globally.
  mov edx, DWORD [rsp + 4]
  mov DWORD [id_base], edx

  ; Set id_mask globally.
  mov edx, DWORD [rsp + 8]
  mov DWORD [id_mask], edx

  ; Read the information we need, skip over the rest.
  lea rdi, [rsp] ; Pointer that will skip over some data.

  mov cx, WORD [rsp + 16] ; Vendor length (v).
  movzx rcx, cx

  mov al, BYTE [rsp + 21]; Number of formats (n).
  movzx rax, al ; Fill the rest of the register with zeroes to avoid garbage values.

  add rdi, 32 ; Skip the connection setup
  add rdi, rcx ; Skip over the vendor information (v).

  ; Skip over padding.
  add rdi, 3
  and rdi, -4

  imul rax, 8 ; sizeof(format) == 8

  add rdi, rax ; Skip over the format information (n*8).

  mov eax, DWORD [rdi] ; Store (and return) the window root id.

; Set the root_visual_id globally.
  mov edx, DWORD [rdi + 32]
  mov DWORD [root_visual_id], edx

  add rsp, 1<<15
  pop rbp ; Restore rbp
  ret

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