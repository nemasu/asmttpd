;asmttpd - Web server for Linux written in amd64 assembly.
;Copyright (C) 2014  nemasu <nemasu@gmail.com>
;
;This file is part of asmttpd.
;
;asmttpd is free software: you can redistribute it and/or modify
;it under the terms of the GNU General Public License as published by
;the Free Software Foundation, either version 2 of the License, or
;(at your option) any later version.
;
;asmttpd is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with asmttpd.  If not, see <http://www.gnu.org/licenses/>.

section .text

sys_sendfile: ;rdi - outfd, rsi - infd, rdx - file size
	stackpush
	mov r10, rdx
	xor rdx, rdx
	mov rax, SYS_SENDFILE
	syscall
	stackpop
	ret

sys_get_file_size: ;rdi - fd, rax - size
	stackpush
	xor rsi, rsi
	mov rdx, LSEEK_END
	mov rax, SYS_LSEEK
	syscall
	stackpop
	ret

sys_lseek:; rdi - fd, rsi - offset
	stackpush
	mov rdx, LSEEK_SET
	mov rax, SYS_LSEEK
	syscall
	stackpop
	ret

sys_open:
	stackpush
	mov rsi, OPEN_RDONLY ;flags 	
	mov rax, SYS_OPEN
	syscall
	stackpop
	ret

sys_close:
	stackpush
	mov rax, SYS_CLOSE
	syscall
	stackpop
	ret

sys_send:
	stackpush
	xor r10, r10
	xor r8, r8
	xor r9, r9
	mov rax, SYS_SENDTO
	syscall
	stackpop
	ret

sys_recv:
	stackpush
	xor r10, r10 ; flags
	xor r8, r8
	xor r9, r9
	mov rax, SYS_RECVFROM
	syscall
	stackpop
	ret

sys_accept:
	stackpush
	mov rdi, [listen_socket]
	xor rsi, rsi
	xor rdx, rdx
	mov rax, SYS_ACCEPT
	syscall
	stackpop
	ret

sys_listen:
	stackpush
	mov rdi, [listen_socket]
	mov rsi, 100000000;backlog
	mov rax, SYS_LISTEN
	syscall
	stackpop
	ret

sys_bind_server:
	stackpush
	mov rdi, [listen_socket]
	mov rsi, sockaddr_in
	mov rdx, 16
	mov rax, SYS_BIND
	syscall
	stackpop
	ret

sys_create_tcp_socket:
	stackpush
	mov rdi, AF_INET
	mov rsi, SOCK_STREAM
	mov rdx, PROTO_TCP
	mov rax, SYS_SOCKET
	syscall
	stackpop
	ret

sys_open_directory:;rdi = path, rax = ret ( fd )
	stackpush
	mov rsi, OPEN_DIRECTORY | OPEN_RDONLY ;flags 
	mov rax, SYS_OPEN
	syscall
	stackpop
	ret

sys_write:
	stackpush
	mov rdx, rsi ;length
	mov rsi, rdi ;buffer
	mov rdi, FD_STDOUT
	mov rax, SYS_WRITE
	syscall
	stackpop
	ret

sys_nanosleep:
	stackpush
	mov qword [tv_usec], rdi
	mov qword [tv_sec],0
	xor rsi, rsi
	mov rdi, timeval
	mov rax, SYS_NANOSLEEP
	syscall
	stackpop
	ret

sys_sleep:
	stackpush
	mov qword [tv_sec], rdi
	mov qword [tv_usec],0
	xor rsi, rsi
	mov rdi, timeval
	mov rax, SYS_NANOSLEEP
	syscall
	stackpop
	ret

sys_mmap_mem:
	stackpush
	mov rsi, rdi                                                    ;Size
	xor rdi, rdi                                                    ;Preferred address (don't care)
	mov rdx, MMAP_PROT_READ | MMAP_PROT_WRITE                       ;Protection Flags
	mov r10, MMAP_MAP_PRIVATE | MMAP_MAP_ANON                       ;Flags
	xor r8, r8
	dec r8                                                          ;-1 fd becasue of MMAP_MAP_ANON
	xor r9, r9                                                      ;Offset
	mov rax, SYS_MMAP
	syscall
	stackpop
	ret

sys_mmap_stack:
	stackpush
	mov rsi, rdi                                                    ;Size
	xor rdi, rdi                                                    ;Preferred address (don't care)
	mov rdx, MMAP_PROT_READ | MMAP_PROT_WRITE                       ;Protection Flags
	mov r10, MMAP_MAP_PRIVATE | MMAP_MAP_ANON | MMAP_MAP_GROWSDOWN  ;Flags
	xor r8, r8
	dec r8                                                          ;-1 fd becasue of MMAP_MAP_ANON
	xor r9, r9                                                      ;Offset
	mov rax, SYS_MMAP
	syscall
	stackpop
	ret

sys_clone: 
	mov r14, rdi      ;Address of the thread_func
	mov r15, rsi      ;Thread Param
	mov rdi, THREAD_STACK_SIZE
	call sys_mmap_stack
	mov rsi, rax       ;Set newly allocated memory
	mov rdi, CLONE_FILES | CLONE_VM | CLONE_FS | CLONE_THREAD | CLONE_SIGHAND | SIGCHILD ;Flags
	xor r10, r10 ;parent_tid
	xor r8,  r8 ;child_tid
	xor r9,  r9 ;regs
	mov rax, SYS_CLONE
	syscall
	cmp rax, 0 ;If ret is not 0, then it's the ID of the new thread
	jnz parent
	push r14     ;Else,  set new return address
	mov rdi, r15 ;and set param
	ret          ;Return to thread_proc
parent:
	ret

