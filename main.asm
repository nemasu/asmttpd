
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

%include "constants.asm"
%include "macros.asm"

%define ASMTTPD_VERSION "0.04"

%define LISTEN_PORT 0x5000 ; PORT 80, network byte order

; Worker thread count should reflect the amount of RAM you have
; eg. 2GB of RAM available to daemon with THREAD_BUFFER_SIZE at 11534336(11MB) = ~180 threads
%define THREAD_POOL_SIZE 100 ; Number of worker threads

;Follwing amd64 syscall standards for internal function calls: rdi rsi rdx r10 r8 r9
section .data

	%include "data.asm"

section .bss

	%include "bss.asm"

section .text

	%include "string.asm"
	%include "http.asm"
	%include "syscall.asm"
	%include "mutex.asm"
	;%include "debug.asm"

global  _start

_start:
	
	mov rdi, start_text
	mov rsi, start_text_len
	call print_line

	mov rdi, [rsp]    ;Num of args
	cmp rdi,2         ;Exit if no argument, should be directory location
	jne exit_with_help

	mov rax, [rsp+16] ;Directory (first) parameter
	mov [directory_path], rax 

	mov rdi, msg_using_directory
	mov rsi, msg_using_directory_len
	call sys_write
	
	mov rdi, [directory_path]
	call get_string_length
	mov rsi, rax
	call print_line


	; Register signal handlers ( just close all other threads by jumping to SYS_EXIT_GROUP )
	mov r10, 8 ; sizeof(sigset_t) displays 128, but strace shows 8 ... so 8 it is! -_-
	xor rdx, rdx
	mov rax, exit
	mov [sa_handler], rax
	mov rsi, sigaction
	mov rdi, SIGINT
	mov rax, SYS_RT_SIGACTION
	syscall
	mov rdi, SIGTERM
	mov rax, SYS_RT_SIGACTION
	syscall

		
	;Create queue for thread pool.
	mov rdi, QUEUE_SIZE
	call sys_mmap_mem
	cmp rax, -1
	je exit
	mov [queue_min], rax
	mov [queue_start], rax
	mov [queue_end], rax
	
	add rax, QUEUE_SIZE
	mov [queue_max], rax

	;Try opening directory
	mov rdi, [directory_path]
	call sys_open_directory

	cmp rax, 0
	jl exit_with_no_directory_error

	;Create socket
	call sys_create_tcp_socket
	cmp rax, 0
	jl exit_error
	mov [listen_socket], rax

	;Bind to port 80
	call sys_bind_server
	cmp rax, 0
	jl exit_error
	
	;Start listening
	call sys_listen

	;Create threads for thread pool
	mov r10, THREAD_POOL_SIZE
	
	thread_pool_setup:
	push r10
	
	mov rdi, worker_thread
	xor rsi, rsi
	call sys_clone
	
	pop r10
	dec r10
	cmp r10, 0
	
	jne thread_pool_setup

main_thread:
	

	call sys_accept
	;check ret fav
	mov rdi, rax
	cmp rdi, 0
	jl main_thread

	call mutex_enter
	
	;add fd to queue
	mov rsi, [queue_end]
	mov [rsi], rdi

	;Adjust end pointer
	mov rdi, [queue_end]
	inc rdi
	mov [queue_end], rdi
	
	call mutex_leave

	call sys_trigger_signal

	jmp main_thread

worker_thread:
	
	mov rbp, rsp
	sub rsp, 16
	mov QWORD [rbp-16], 0 ; Used for pointer to recieve buffer

	mov rdi, THREAD_BUFFER_SIZE
	call sys_mmap_mem
	mov QWORD [rbp-16], rax

	mov QWORD [rbp-8], 0x00    ; used for socket fd, when we get one.

worker_thread_start:

	call sys_wait_for_signal

	call mutex_enter
	mov rdi, QWORD [queue_start]
	mov rsi, QWORD [queue_end]
	cmp rdi, rsi
	jne worker_thread_continue

	call mutex_leave
	
	
	jmp worker_thread_start

worker_thread_continue:
	
	mov rdi, [rdi]
	mov [rbp-8], rdi ; save fd

	;fiddle with queue, currently pops it off the end ... oh well.
	mov rdi, [queue_end]
	dec rdi
	mov [queue_end], rdi

	call mutex_leave

	;HTTP Stuff starts here
	mov rdi, QWORD [rbp-8] ;fd
	mov rsi, [rbp-16]      ;buffer
	mov rdx, THREAD_BUFFER_SIZE    ;size
	call sys_recv

	cmp rax, 0
	jle worker_thread_close

	;stackpush
	;push rax
	;mov rdi, rsi
	;mov rsi, rax
	;call print_line ; debug
	;pop rax
	;stackpop
	
	; add null and save length
	mov r11, rax ; save original received length
	inc r11
	mov rdi, [rbp-16]
	add rdi, r11
	mov BYTE [rdi], 0x00

	;Find request
	mov rax, 0x2F ; '/' character
	mov rdi, [rbp-16] ;scan buffer
	mov rcx, -1         ;Start count
	cld               ;Increment rdi
	repne scasb
	jne worker_thread_close ;TODO: change to 400 error
	mov rax, -2
	sub rax, rcx      ;Get the length

	mov r8, rax ; start offset for requested file
	mov rdi, [rbp-16]
	add rdi, r8
	mov rax, 0x20  ;'space' character
	mov rcx, -1
	cld
	repne scasb
	jne worker_thread_close ;TODO change to 400 error
	mov rax, -1
	sub rax, rcx
	mov r9, rax
	add r9, r8  ;end offset

	;TODO: Assuming it's a file, need directory handling too
	;Also, we're going to try and read the whole thing, needs to be chunked.
	
	mov rdi, [rbp-16]
	add rdi, r11 ; end of buffer, lets use it!
	mov r12, r11 ; keeping count

	mov rsi, [directory_path]

	worker_thread_append_directory_path:
	lodsb
	stosb
	inc r12
	cmp rax, 0x00
	jne worker_thread_append_directory_path

	dec r12 ; get rid of 0x00

	; Adds the file to the end of buffer ( where we juts put the document prefix )
	mov rsi, [rbp-16]
	add rsi, r8  ; points to beginning of path
	mov rdi, [rbp-16]
	add rdi, r12 ;go to end of buffer
	mov rcx, r9
	sub rcx, r8
	add r12, rcx
	rep movsb

	dec r12 ; exclude space character
	mov rdi, [rbp-16]
	add rdi, r12
	mov BYTE [rdi], 0x00 ; add null

	mov r9, r11 ; saving offset into a stack saved register
	; [rbp-16] + r9 now holds string for file opening

	; Simple request logging
	mov rdi, msg_request_log
	mov rsi, msg_request_log_len
	call sys_write
	mov rdi, [rbp-16]
	add rdi, r9
	call get_string_length
	mov rsi, rax
	call print_line
	;-----Simple logging
	
	worker_thread_remove_pre_dir:
	mov rdi, [rbp-16]
	add rdi, r9
	mov rsi, filter_prev_dir ; remove any '../'
	call string_remove
	cmp rax, 0
	jne worker_thread_remove_pre_dir


	mov rdi, [rbp-16]
	add rdi, r9
	call detect_content_type
	mov r8, rax ;r8: Content Type

	worker_thread_response:

	;Try to open requested file
	mov rdi, [rbp-16]
	add rdi, r9
	call sys_open
	cmp rax, 0

	jl worker_thread_404_response ;file not found, so 404
	
	; Done with buffer offsets, put response and data into it starting at beg
	mov r10, rax ; r10: file fd

	;Determine if request requires a 206 response
	
	mov rdi, r10 ; fd
	call sys_get_file_size
	push rax

	;Basically if "Range:" is in the header	
	mov rdi, [rbp-16]
	mov rsi, header_range_search
	call string_contains

	pop rdi	
	cmp rax, -1
	jne worker_thread_206_response 

	jmp worker_thread_200_response ;else, we're good to go

	;---------404 Response Start-------------
	worker_thread_404_response:
	
	mov rdi, [rbp-16]
	call create_http404_response
	
	;Send response
	mov rdi, [rbp-8]
	mov rsi, [rbp-16]
	mov rdx, rax
	call sys_send
	
	;and exit
	jmp worker_thread_close
	;---------404 Response End--------------


	;---------206 Response Start------------
	worker_thread_206_response:
	; r8: content type , r10: fd, rax: Range: start
	push r10
	push r8

	mov r8, rdi ; r8 now size
	
	cmp rax, -1
	je worker_thread_206_no_bytes_search_cont
	
	; find 'bytes='
    mov rdi, [rbp-16]
	add rdi, rax
    push rsi
    mov rsi, find_bytes_range
    call string_contains
    pop rsi
    cmp rax, -1
    je worker_thread_206_no_bytes_search_cont

    add rdi, rax
    add rdi, 6 ; go to number

    push rdi ; save beg of first number

	mov rax, 0
    create_http206_response_lbeg:
    inc rdi
	inc rax
	cmp rax, 1000 ; todo tweak this number
	jge worker_thread_close_file
    cmp BYTE [rdi], 0x2D ; look for '-'
    jne create_http206_response_lbeg

    mov BYTE [rdi], 0x00 ; replace '-' with null
    mov rbx, rdi ; save new beg
    inc rbx
    pop rdi ; restore beg of first number, convert to int
    call string_atoi

    mov rdi, rbx ; char after null
    mov rbx, rax ; rbx: from byte range
   
    push rdi ; save beginning of 2nd byte range
   
    create_http206_response_rbeg:
    inc rdi
    cmp BYTE [rdi], 0x0a ; look for end of line
    jne create_http206_response_rbeg

    dec rdi
    mov BYTE [rdi], 0x00; replace end with null
    pop rdi ; restore 2nd byte range

    call string_atoi

    mov rcx,rax ; rcx: to byte range, -1 if there is no end
	;byte range: rbx -> rcx(-1 if to end)
	jmp worker_thread_206_bytes_cont

	worker_thread_206_no_bytes_search_cont:
	; for no bytes entry, but is too big to fit
	mov rbx, 0
	mov rcx, -1 ; just go from 0 to as much as possible

	worker_thread_206_bytes_cont:
	
	mov r9, THREAD_BUFFER_SIZE-HEADER_RESERVED_SIZE
	
	cmp rcx, -1
	jne skip_end_range_update
	;Update end
	;max end is THREAD_BUFFER_SIZE minus HEADER_RESERVED_SIZE
	;if file is smaller, then awesome, else make it that size
	
	mov rcx, r8
	dec rcx ; zero based
	cmp rcx, r9
	jl skip_end_range_update ; if it fits, awesome
	mov rcx, r9
	dec rcx ; zero based...doesn't really matter in this case though

	skip_end_range_update:

	mov rax, rcx
	inc rax
	sub rax, rbx
	cmp rax, r9
	jg worker_thread_close_file ; todo return 416

	cmp rbx, rcx
	jg worker_thread_close_file ; todo return 416

	inc rcx ; take into acount zero based 'to'
	
	cmp rcx, r8
	jg worker_thread_close_file ; todo: return 413
	dec rcx

	inc rbx
	cmp rbx, r8
	jg worker_thread_close_file ; todo: return 416
	dec rbx

	mov rdi, r8 ; total filesize
	pop r9  ; type
	push r10; still need fd

	mov r10, rdi  ;total
	mov rdi, [rbp-16]
	mov rsi, rbx ;from
	mov rdx, rcx ;to
	call create_http206_response
	mov r9, rax ; r9: header size

	pop rdi ; pop fd
	;rsi already has offset, or 'from'
	call sys_lseek
	
	sub rdx, rsi ; read to - from + 1
	inc rdx

	mov rsi, [rbp-16]
	add rsi, r9
	call sys_read
	add r9, rax ; add to read bytes the header size(r9)

	;Send it
	mov rdi, [rbp-8]
	mov rsi, [rbp-16]
	mov rdx, r9
	call sys_send

	;stackpush
	;push rax
	;mov rdi, rsi
	;mov rsi, r9
	;call print_line ; debug
	;pop rax
	;stackpop

	pop r10 ; restore fd
	
	jmp worker_thread_close_file
	;---------206 Response End--------------


	;---------200 Response Start------------
	worker_thread_200_response:

	;rdi - total filesize
	push rdi

	;Seek to beg of file
	mov rdi, r10 ; fd
	mov rsi, 0
	call sys_lseek
	
	;Create Response
	mov rdi, [rbp-16]
	mov rsi, r8 ; type, figured out above
	pop rdx ; total file size
	call create_http200_response

	mov r8, rax ; header size

	worker_thread_200_repsonse_stream:
	add rdi, r8 ; add length to address
	mov rsi, rdi
	mov rdi, r10 ; set fd
	mov rdx, THREAD_BUFFER_SIZE-HEADER_RESERVED_SIZE
	call sys_read

	sub r12, rax
	
	cmp r8, 0
	
	je worker_thread_200_no_header
	add r8, rax
	jmp worker_thread_200_continue

	worker_thread_200_no_header:
	mov r8, rax

	worker_thread_200_continue:
	cmp rax, 0
	jle worker_thread_close_file ; if there's nothing left to read, we're done

	;Send response
	mov rdi, [rbp-8]
	mov rsi, [rbp-16]
	mov rdx, r8
	call sys_send
	mov r8,	0 ; set no header
	mov rax, 0 ; header size
	mov rdi, [rbp-16]
	cmp r12, 0 ; running total
	jne worker_thread_200_repsonse_stream
	
	;stackpush
	;push rax
	;mov rdi, rsi
	;mov rsi, r8
	;call print_line ; debug
	;pop rax
	;stackpop

	
	;---------200 Response End--------------

	worker_thread_close_file:
	;Close File
	mov rdi, r10
	call sys_close

	;Close Socket
	worker_thread_close:
	mov rdi, [rbp-8]
	call sys_close
	
	jmp worker_thread_start 
	
exit_with_no_directory_error:
	mov rdi, msg_not_a_directory
	mov rsi, msg_not_a_directory_len
	call print_line
	jmp exit

exit_with_help:
	mov rdi, msg_help
	mov rsi, msg_help_len
	call print_line
	jmp exit

exit_error:
	mov rdi, msg_error
	mov rsi, msg_error_len
	call print_line

	mov rdi, -1
	mov rax, SYS_EXIT_GROUP
	syscall
	jmp exit

exit_thread:

	xor rdi, rdi
	mov rax, SYS_EXIT
	syscall
	jmp exit

exit:
	
	mov rdi, [listen_socket]
	call sys_close

	xor rdi, rdi 
	mov rax, SYS_EXIT_GROUP
	syscall

