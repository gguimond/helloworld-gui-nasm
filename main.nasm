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
  call x11_connect_to_server
  mov r15, rax ; Store the socket file descriptor in r15.

  mov rdi, rax
  call x11_send_handshake

  mov r12d, eax ; Store the window root id in r12.

  call x11_next_id
  mov r13d, eax ; Store the gc_id in r13.

  call x11_next_id
  mov r14d, eax ; Store the font_id in r14.

  mov rdi, r15
  mov esi, r14d
  call x11_open_font

  mov rdi, r15
  mov esi, r13d
  mov edx, r12d
  mov ecx, r14d
  call x11_create_gc

  call x11_next_id
  mov ebx, eax ; Store the window id in ebx.

  mov rdi, r15 ; socket fd
  mov esi, eax
  mov edx, r12d
  mov ecx, [root_visual_id]
  mov r8d, 200 | (200 << 16) ; x and y are 200
  %define WINDOW_W 800
  %define WINDOW_H 600
  mov r9d, WINDOW_W | (WINDOW_H << 16)
  call x11_create_window

  mov rdi, r15 ; socket fd
  mov esi, ebx
  call x11_map_window

  call print_hello 

  mov rax, SYSCALL_EXIT
  mov rdi, 0
  syscall

die:
  mov rax, SYSCALL_EXIT
  mov rdi, 1
  syscall  

; Map a X11 window.
; @param rdi The socket file descriptor.
; @param esi The window id.
x11_map_window:
static x11_map_window:function
  push rbp
  mov rbp, rsp

  sub rsp, 16

  %define X11_OP_REQ_MAP_WINDOW 0x08
  mov DWORD [rsp + 0*4], X11_OP_REQ_MAP_WINDOW | (2<<16)
  mov DWORD [rsp + 1*4], esi

  mov rax, SYSCALL_WRITE
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, 2*4
  syscall

  cmp rax, 2*4
  jnz die

  add rsp, 16

  pop rbp
  ret

; Create the X11 window.
; @param rdi The socket file descriptor.
; @param esi The new window id.
; @param edx The window root id.
; @param ecx The root visual id.
; @param r8d Packed x and y.
; @param r9d Packed w and h.
x11_create_window:
static x11_create_window:function
  push rbp
  mov rbp, rsp

  %define X11_OP_REQ_CREATE_WINDOW 0x01
  %define X11_FLAG_WIN_BG_COLOR 0x00000002
  %define X11_EVENT_FLAG_KEY_RELEASE 0x0002
  %define X11_EVENT_FLAG_EXPOSURE 0x8000
  %define X11_FLAG_WIN_EVENT 0x00000800
  
  %define CREATE_WINDOW_FLAG_COUNT 2
  %define CREATE_WINDOW_PACKET_U32_COUNT (8 + CREATE_WINDOW_FLAG_COUNT)
  %define CREATE_WINDOW_BORDER 1
  %define CREATE_WINDOW_GROUP 1

  sub rsp, 12*8

  mov DWORD [rsp + 0*4], X11_OP_REQ_CREATE_WINDOW | (CREATE_WINDOW_PACKET_U32_COUNT << 16)
  mov DWORD [rsp + 1*4], esi
  mov DWORD [rsp + 2*4], edx
  mov DWORD [rsp + 3*4], r8d
  mov DWORD [rsp + 4*4], r9d
  mov DWORD [rsp + 5*4], CREATE_WINDOW_GROUP | (CREATE_WINDOW_BORDER << 16)
  mov DWORD [rsp + 6*4], ecx
  mov DWORD [rsp + 7*4], X11_FLAG_WIN_BG_COLOR | X11_FLAG_WIN_EVENT
  mov DWORD [rsp + 8*4], 0
  mov DWORD [rsp + 9*4], X11_EVENT_FLAG_KEY_RELEASE | X11_EVENT_FLAG_EXPOSURE


  mov rax, SYSCALL_WRITE
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, CREATE_WINDOW_PACKET_U32_COUNT*4
  syscall

  cmp rax, CREATE_WINDOW_PACKET_U32_COUNT*4
  jnz die

  add rsp, 12*8

  pop rbp
  ret

; Create a X11 graphical context.
; @param rdi The socket file descriptor.
; @param esi The graphical context id.
; @param edx The window root id.
; @param ecx The font id.
x11_create_gc:
static x11_create_gc:function
  push rbp
  mov rbp, rsp

  sub rsp, 8*8

%define X11_OP_REQ_CREATE_GC 0x37
%define X11_FLAG_GC_BG 0x00000004
%define X11_FLAG_GC_FG 0x00000008
%define X11_FLAG_GC_FONT 0x00004000
%define X11_FLAG_GC_EXPOSE 0x00010000

%define CREATE_GC_FLAGS X11_FLAG_GC_BG | X11_FLAG_GC_FG | X11_FLAG_GC_FONT
%define CREATE_GC_PACKET_FLAG_COUNT 3
%define CREATE_GC_PACKET_U32_COUNT (4 + CREATE_GC_PACKET_FLAG_COUNT)
%define MY_COLOR_RGB 0x0000ffff

  mov DWORD [rsp + 0*4], X11_OP_REQ_CREATE_GC | (CREATE_GC_PACKET_U32_COUNT<<16)
  mov DWORD [rsp + 1*4], esi
  mov DWORD [rsp + 2*4], edx
  mov DWORD [rsp + 3*4], CREATE_GC_FLAGS
  mov DWORD [rsp + 4*4], MY_COLOR_RGB
  mov DWORD [rsp + 5*4], 0
  mov DWORD [rsp + 6*4], ecx

  mov rax, SYSCALL_WRITE
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, CREATE_GC_PACKET_U32_COUNT*4
  syscall

  cmp rax, CREATE_GC_PACKET_U32_COUNT*4
  jnz die
  
  add rsp, 8*8

  pop rbp
  ret

; Open the font on the server side.
; @param rdi The socket file descriptor.
; @param esi The font id.
x11_open_font:
static x11_open_font:function
  push rbp
  mov rbp, rsp

  %define OPEN_FONT_NAME_BYTE_COUNT 5
  %define OPEN_FONT_PADDING ((4 - (OPEN_FONT_NAME_BYTE_COUNT % 4)) % 4)
  %define OPEN_FONT_PACKET_U32_COUNT (3 + (OPEN_FONT_NAME_BYTE_COUNT + OPEN_FONT_PADDING) / 4)
  %define X11_OP_REQ_OPEN_FONT 0x2d

  sub rsp, 6*8
  mov DWORD [rsp + 0*4], X11_OP_REQ_OPEN_FONT | (OPEN_FONT_NAME_BYTE_COUNT << 16)
  mov DWORD [rsp + 1*4], esi
  mov DWORD [rsp + 2*4], OPEN_FONT_NAME_BYTE_COUNT
  mov BYTE [rsp + 3*4 + 0], 'f'
  mov BYTE [rsp + 3*4 + 1], 'i'
  mov BYTE [rsp + 3*4 + 2], 'x'
  mov BYTE [rsp + 3*4 + 3], 'e'
  mov BYTE [rsp + 3*4 + 4], 'd'


  mov rax, SYSCALL_WRITE
  mov rdi, rdi
  lea rsi, [rsp]
  mov rdx, OPEN_FONT_PACKET_U32_COUNT*4
  syscall

  cmp rax, OPEN_FONT_PACKET_U32_COUNT*4
  jnz die

  add rsp, 6*8

  pop rbp
  ret

; Increment the global id.
; @return The new id.
x11_next_id:
static x11_next_id:function
  push rbp
  mov rbp, rsp

  mov eax, DWORD [id] ; Load global id.

  mov edi, DWORD [id_base] ; Load global id_base.
  mov edx, DWORD [id_mask] ; Load global id_mask.

  ; Return: id_mask & (id) | id_base
  and eax, edx
  or eax, edi

  add DWORD [id], 1 ; Increment id.

  pop rbp
  ret

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

; Create a UNIX domain socket and connect to the X11 server.
; @returns The socket file descriptor.
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