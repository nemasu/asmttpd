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

create_http200_response: ;rdi - pointer to buffer, rsi - type 0 = html, 1 = octet-stream, ret length
	stackpush

	mov r8, rdi ;store buffer pointer
	mov r10, rsi ;type
	mov rax, 0
	
	mov rsi, http_ok
	mov rdi, r8
	mov rcx, http_ok_len
	add rax, rcx
	rep movsb

	mov rsi, server_header
	mov rdi, r8   ;buffer location
	add rdi, rax  ;add offset
	mov rcx, server_header_len
	add rax, rcx
	rep movsb
	
	mov rsi, connection_header
	mov rdi, r8
	add rdi, rax  ;add offset
	mov rcx, connection_header_len
	add rax, rcx
	rep movsb

	cmp r10, 1
	je create_http200_response_octect

	mov rsi, content_type_html
	mov rcx, content_type_html_len
	jmp create_http200_response_cont

	create_http200_response_octect:
	
	mov rsi, content_type_stream
	mov rcx, content_type_stream_len

	create_http200_response_cont:
	mov rdi, r8
	add rdi, rax ;add offset
	add rax, rcx
	rep movsb

	stackpop
	ret

create_http404_response: ;rdi - pointer to buffer
	stackpush

	mov r8, rdi ;store buffer pointer
	mov rax, 0
	
	mov rsi, http_not_found
	mov rdi, r8
	mov rcx, http_not_found_len
	add rax, rcx
	rep movsb

	mov rsi, server_header
	mov rdi, r8   ;buffer location
	add rdi, rax  ;add offset
	mov rcx, server_header_len
	add rax, rcx
	rep movsb
	
	mov rsi, connection_header
	mov rdi, r8
	add rdi, rax  ;add offset
	mov rcx, connection_header_len
	add rax, rcx
	rep movsb
	
	stackpop
	ret
