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

%include "constants.asm"
%include "macros.asm"

%define ASMTTPD_VERSION "0.4.6"

%define THREAD_COUNT 10 ; Number of worker threads

;Follwing amd64 syscall standards for internal function calls: rdi rsi rdx r10 r8 r9

section .data
    %include "data.asm"
    
section .bss
    %include "bss.asm"

section .text
    %include "string.asm"
    %include "http.asm"
    %include "syscall.asm"
    %include "dirent.asm"
    ;%include "mutex.asm"
    ;%include "debug.asm"

global  _start

_start:

    mov QWORD [one_constant], 1

    mov rdi, start_text
    mov rsi, start_text_len
    call print_line

    mov rdi, [rsp]    ;Num of args
    cmp rdi,3         ;Exit if no argument, should be directory location
    jne exit_with_help
        
    mov rdi, [rsp+16+8]; Port (second) parameter
    call string_atoi
    xchg al, ah
    mov [listen_port], eax
    
    mov rax, [rsp+16] ;Directory (first) parameter
    mov [directory_path], rax
    
    ; Register signal handlers ( just close all other threads by jumping to SYS_EXIT_GROUP )
    mov r10, 8 ; sizeof(sigset_t) displays 128, but strace shows 8 ... so 8 it is! -_-
    xor rdx, rdx
    mov QWORD [sa_handler], exit
    mov rsi, sigaction
    mov rdi, SIGINT
    mov rax, SYS_RT_SIGACTION
    syscall
    mov rdi, SIGTERM
    mov rax, SYS_RT_SIGACTION
    syscall
    mov QWORD [sa_handler], SIGIGN
    mov rdi, SIGPIPE
    mov rax, SYS_RT_SIGACTION
    syscall
    
    ;Try opening directory
    mov rdi, [directory_path]
    mov rdx, OPEN_DIRECTORY
    call sys_open_directory

    cmp rax, 0
    jl exit_with_no_directory_error

    ;Create socket
    call sys_create_tcp_socket
    cmp rax, 0
    jl exit_error
    mov [listen_socket], rax

    ;reuseaddr
    mov rdi, [listen_socket]
    call sys_reuse

    ;Bind to port
    call sys_bind_server
    cmp rax, 0
    jl exit_bind_error
    
    ;Start listening
    call sys_listen

    ;Create threads
    mov r10, THREAD_COUNT
    
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
    

    mov rdi, 10
    call sys_sleep

    jmp main_thread

worker_thread:
    
    mov rbp, rsp
    sub rsp, 16
    ;Offsets: 8 - socket fd, 16 - buffer

    mov QWORD [rbp-16], 0 ; Used for pointer to recieve buffer

    mov rdi, THREAD_BUFFER_SIZE+2+URL_LENGTH_LIMIT+DIRECTORY_LENGTH_LIMIT+DIRECTORY_LIST_BUFFER+CUSTOM_CONTENT_BUFFER ; Allow room to append null, and to create path
    call sys_mmap_mem
    mov QWORD [rbp-16], rax

worker_thread_start:

    call sys_accept

    mov [rbp-8], rax ; save fd
    
    mov rdi, rax
    call sys_cork ; cork it

worker_thread_continue:
    
    ;HTTP Stuff starts here
    mov rdi, QWORD [rbp-8] ;fd
    mov rsi, [rbp-16]      ;buffer
    mov rdx, THREAD_BUFFER_SIZE    ;size
    call sys_recv

    cmp rax, 0
    jle worker_thread_close

    push rax ; save original received length
    
    ;stackpush
    ;push rax
    ;mov rdi, rsi
    ;mov rsi, rax
    ;call print_line ; debug
    ;pop rax
    ;stackpop

    ; add null
    mov rdi, [rbp-16]
    add rdi, rax
    mov BYTE [rdi], 0x00

    ;Make sure its a valid request
    mov rdi, [rbp-16]
    mov rsi, crlfx2
    call string_ends_with
    cmp rax, 1
    jne worker_thread_400_response

    mov rdi, [rbp-16]
    call get_request_type
    mov [request_type], rax
    cmp BYTE [request_type], REQ_UNK
    je worker_thread_400_response

    ;Find request
    mov rax, 0x2F ; '/' character
    mov rdi, [rbp-16] ;scan buffer
    mov rcx, -1         ;Start count
    cld               ;Increment rdi
    repne scasb
    jne worker_thread_400_response
    mov rax, -2
    sub rax, rcx      ;Get the length

    mov r8, rax ; start offset for requested file
    mov rdi, [rbp-16]
    add rdi, r8
    mov rax, 0x20  ;'space' character
    mov rcx, -1
    cld
    repne scasb
    jne worker_thread_400_response
    mov rax, -1
    sub rax, rcx
    mov r9, rax
    add r9, r8  ;end offset
    
    pop r11 ; restore orig recvd length
    mov rdi, [rbp-16]
    add rdi, r11 ; end of buffer, lets use it!
    mov r12, r11 ; keeping count

    mov rsi, [directory_path]
    xor r15, r15 ; Make sure directory path does not exceed DIRECTORY_LENGTH_LIMIT

    worker_thread_append_directory_path:
    inc r15
    cmp r15, DIRECTORY_LENGTH_LIMIT
    je worker_thread_400_response
    lodsb
    stosb
    inc r12
    cmp al, 0x00
    jne worker_thread_append_directory_path

    dec r12 ; get rid of 0x00

    ;Check if default document needed
    cmp r9, [request_offset] ; Offset of document requested
    jne no_default_document
    mov rsi, default_document
    mov rdi, [rbp-16]
    add rdi, r12
    mov rcx, default_document_len
    add r12, rcx
    rep movsb
    mov r9, r11 ; saving offset into a stack saved register
    jmp worker_thread_remove_pre_dir

    no_default_document:

    ; Adds the file to the end of buffer ( where we juts put the document prefix )
    mov rsi, [rbp-16]
    add rsi, r8  ; points to beginning of path
    mov rdi, [rbp-16]
    add rdi, r12 ;go to end of buffer
    mov rcx, r9
    sub rcx, r8
    cmp rcx, URL_LENGTH_LIMIT ; Make sure this does not exceed URL_PATH_LENGTH
    jg worker_thread_400_response
    add r12, rcx
    rep movsb

    dec r12 ; exclude space character
    mov rdi, [rbp-16]
    add rdi, r12
    mov BYTE [rdi], 0x00 ; add null

    mov r9, r11 ; saving offset into a stack saved register
    ; [rbp-16] + r9 now holds string for file opening

    worker_thread_remove_pre_dir:
    
    ;-----Simple request logging
    ;mov rdi, msg_request_log
    ;mov rsi, msg_request_log_len
    ;call sys_write
    ;mov rdi, [rbp-16]
    ;add rdi, r9
    ;call get_string_length
    ;mov rsi, rax
    ;call print_line
    ;-----End Simple logging
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

    cmp r8, CONTENT_TYPE_OCTET_STREAM
    jne worker_thread_response

    worker_thread_test_dir:
    mov rdi, [rbp-16]
    add rdi, r9
    mov rdx, OPEN_RDONLY | OPEN_DIRECTORY
    call sys_open_directory
    cmp rax, 0
    jl worker_thread_response ; TODO error cannot open dir - 404?

    ; Check if request ends in '/' and if not respond 301, which in turn triggers another request with a trailing '/'
    push rax
    mov rdi, [rbp-16]
    add rdi, r9
    call get_string_length
    add rdi, rax
    dec rdi
    cmp byte[rdi], 0x2f
    jne worker_thread_301_response
    pop rax

    mov rbx, THREAD_BUFFER_SIZE+2+URL_LENGTH_LIMIT+DIRECTORY_LENGTH_LIMIT
    mov rsi, [rbp-16]
    add rsi, rbx
    push r9 ; Save pointer to http buffer
    mov r9, rsi ; Pointer to dir list buffer, first entry contains bytes read

    mov rdi, rax ; fd
    mov rdx, DIRECTORY_LIST_BUFFER
    call sys_get_dir_listing
    cmp rax, 0 ; rax = bytes read
    jl worker_thread_response ; TODO error no bytes read - 404?

    mov [dir_ent_pointer], r9
    mov [dir_ent_size], rax

    pop r9
    jmp worker_thread_200_response_dir_list

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
    xor rsi, rsi
    mov rdx, LSEEK_END
    call sys_lseek
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

    ;---------301 Response Start-------------
    worker_thread_301_response:

    mov rdi, [rbp-16]
    mov r10, CONTENT_TYPE_HTML
    call create_http301_response

    ;Send response
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    ;and exit
    jmp worker_thread_close
    ;---------301 Response End--------------

    ;---------206 Response Start------------
    worker_thread_206_response:
    ; r8: content type , r10: fd, rax: Range: start
    
    push r10
    push r8

    mov r8, rdi ; r8 now size
    
    ;Seek to beg of file
    mov rdi, r10 ; fd
    mov rsi, 0
    mov rdx, LSEEK_SET
    call sys_lseek

    ; find 'bytes='
    mov rdi, [rbp-16]
    add rdi, rax
    mov rsi, find_bytes_range
    call string_contains
    cmp rax, -1
    je worker_thread_400_response

    add rdi, rax
    add rdi, 6 ; go to number

    push rdi ; save beg of first number

    mov rax, 0
    create_http206_response_lbeg:
    inc rdi
    inc rax
    cmp rax, 200 ; todo tweak this number
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


    cmp rcx, -1
    jne worker_thread_206_skip_unknown_end
    mov rcx, r8
    dec rcx ; zero based
    worker_thread_206_skip_unknown_end:

    cmp rcx, r8
    jge worker_thread_413_response

    cmp rbx, rcx
    jg worker_thread_416_response

    pop r9 ; type
    mov r10, r8  ;total
    mov rdi, [rbp-16]
    mov rsi, rbx ;from
    mov r13, rsi ; r13: from offset
    mov rdx, rcx ;to
    mov r12, rcx ; r12: to byte range
    call create_http206_response
    mov r9, rax ; r9: header size

    sub r12, r13 ; r12: amount to send
    inc r12; zero based

    ;Send it
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, r9
    call sys_send
    
    pop rdi ; sock fd - stack is empty now
    push rdi ; save it so we can close it

    mov rsi, r13 ; file offset ( range 'from' )
    mov rdx, LSEEK_SET
    call sys_lseek


    mov rdx, r12 ;file size to send
    mov rsi, rdi
    mov rdi, [rbp-8]
    call sys_sendfile

    ;stackpush
    ;push rax
    ;mov rdi, rsi
    ;mov rsi, r9
    ;call print_line ; debug
    ;pop rax
    ;stackpop
    
    pop r10; restore fd for close   
    jmp worker_thread_close_file
    ;---------206 Response End--------------

    ;------200 Dir List Response Start------
    worker_thread_200_response_dir_list:
    mov rdi, [rbp-16]
    mov rbx, THREAD_BUFFER_SIZE+2+URL_LENGTH_LIMIT+DIRECTORY_LENGTH_LIMIT+DIRECTORY_LIST_BUFFER
    inc rbx ; zero pad start
    add rdi, rbx
    push rdi ; save start of directory list buffer for later

    call generate_dir_entries ; rax = new length
    push rax ; save length of contents for later

    ;Create Response
    mov rdi, [rbp-16]
    mov rsi, CONTENT_TYPE_HTML ; as we are sending custom HTML, change type
    mov rdx, rax ; total file size
    call create_http200_response

    mov r8, rax ; header size

    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    ;Send the html formatted directory contents
    pop rax ; restore buffer pointer and length
    pop rdi
    mov rsi, rdi
    mov rdi, [rbp-8]
    mov rdx, rax
    call sys_send
    jmp worker_thread_close
    ;-------200 Dir List Response End-------

    ;---------200 Response Start------------
    worker_thread_200_response:

    ;rdi - total filesize
    push rdi

    ;Seek to beg of file
    mov rdi, r10 ; fd
    mov rsi, 0
    mov rdx, LSEEK_SET
    call sys_lseek
    
    ;Create Response
    mov rdi, [rbp-16]
    mov rsi, r8 ; type, figured out above
    pop rdx ; total file size
    push rdx ; save for sendfile
    call create_http200_response

    mov r8, rax ; header size

    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    cmp rax, 0
    jle worker_thread_close_file

       cmp BYTE [request_type], REQ_HEAD
    je worker_thread_close_file

    mov rdi, [rbp-8]
    mov rsi, r10
    pop rdx
    call sys_sendfile
    jmp worker_thread_close_file
    ;---------200 Response End--------------

    ;---------400 Response Start------------
    worker_thread_400_response:
    mov rdi, [rbp-16]
    mov rsi, 400
    call create_httpError_response

    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    jmp worker_thread_close
    ;---------400 Response End--------------
    
    ;---------413 Response Start------------
    worker_thread_413_response:
    mov rdi, [rbp-16]
    mov rsi, 413
    call create_httpError_response

    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    jmp worker_thread_close
    ;---------413 Response End--------------
    
    ;---------416 Response Start------------
    worker_thread_416_response:
    mov rdi, [rbp-16]
    mov rsi, 416
    call create_httpError_response

    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, rax
    call sys_send

    jmp worker_thread_close
    ;---------416 Response End--------------

    worker_thread_close_file:
    ;Uncork
    mov rdi, [rbp-8]
    call sys_uncork
    
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

exit_bind_error:
    mov rdi, msg_bind_error
    mov rsi, msg_bind_error_len
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

