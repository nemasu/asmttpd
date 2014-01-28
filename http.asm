;asmttpd - Web server for Linux written in amd64 assembly.
;Copyright (C) 2014  Nathan Torchia <nemasu@gmail.com>
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

;This writes the text after "Content-Type: " at rsi
detect_content_type: ;rdi - pointer to buffer that contains request, ret - rax: type flag - see create_http200_reponse comments
	stackpush

	mov rsi, extension_htm
	call string_ends_with
	mov r10, 0
	cmp rax, 1
	je detect_content_type_ret

	mov rsi, extension_html
	call string_ends_with
	mov r10, 0
	cmp rax, 1
	je detect_content_type_ret
	
	mov rsi, extension_css
	call string_ends_with
	mov r10, 2
	cmp rax, 1
	je detect_content_type_ret
	
	mov rsi, extension_javascript
	call string_ends_with
	mov r10, 3
	cmp rax, 1
	je detect_content_type_ret

	mov rsi, extension_xhtml
	call string_ends_with
	mov r10, 4
	cmp rax, 1
	je detect_content_type_ret

	mov rsi, extension_xml
	call string_ends_with
	mov r10, 5
	cmp rax, 1
	je detect_content_type_ret

	mov rsi, extension_gif
	call string_ends_with
	mov r10, 6
	cmp rax, 1
	je detect_content_type_ret
	
	mov rsi, extension_png
	call string_ends_with
	mov r10, 7
	cmp rax, 1
	je detect_content_type_ret
	
	mov rsi, extension_jpeg
	call string_ends_with
	mov r10, 8
	cmp rax, 1
	je detect_content_type_ret
	
	mov rsi, extension_jpg
	call string_ends_with
	mov r10, 8
	cmp rax, 1
	je detect_content_type_ret

	mov r10, 1 ; default to octet-stream
	detect_content_type_ret:
	mov rax, r10
	stackpop
	ret

create_http200_response: ;rdi - pointer to buffer, rsi - type 0 = html, 1 = octet-stream, 2 = css, 3 = javascript, 4 = xhtml, 5 = xml, 
						 ; 6 = gif, 7 = png, 8 = jpeg, ret: length
	stackpush

	mov r10, rsi ;type
	
	mov rsi, http_200  ;First one we copy
	mov rdx, http_200_len
	call string_copy

	mov rsi, server_header
	call string_concat

	mov rsi, connection_header
	call string_concat
	
	mov rsi, content_type
	call string_concat

	cmp r10, 0
	je create_http200_response_html
	cmp r10, 1
	je create_http200_response_octet_stream
	cmp r10, 2
	je create_http200_response_css
	cmp r10, 3
	je create_http200_response_javascript
	cmp r10, 4
	je create_http200_response_xhtml
	cmp r10, 5
	je create_http200_response_xml
	cmp r10, 6
	je create_http200_response_gif
	cmp r10, 7
	je create_http200_response_png
	cmp r10, 8
	je create_http200_response_jpeg
	
	jmp create_http200_response_octet_stream

	
	create_http200_response_html:
	mov rsi, content_type_html
	call string_concat
	jmp create_http200_response_cont
	
	create_http200_response_octet_stream:
	mov rsi, content_type_octet_stream
	call string_concat
	jmp create_http200_response_cont
	
	create_http200_response_css:
	mov rsi, content_type_css
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_javascript:
	mov rsi, content_type_javascript
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_xhtml:
	mov rsi, content_type_xhtml
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_xml:
	mov rsi, content_type_xml
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_gif:
	mov rsi, content_type_gif
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_png:
	mov rsi, content_type_png
	call string_concat
	jmp create_http200_response_cont

	create_http200_response_jpeg:
	mov rsi, content_type_jpeg
	call string_concat
	
	
	create_http200_response_cont:
	
	mov rsi, crlf
	call string_concat

	call get_string_length

	stackpop
	ret

create_http404_response: ;rdi - pointer to buffer
	stackpush

	mov rsi, http_404  ;First one we copy
	mov rdx, http_404_len
	call string_copy

	mov rsi, server_header
	call string_concat

	mov rsi, connection_header
	call string_concat

	mov rsi, crlf
	call string_concat

	mov rsi, http_404_text
	call string_concat

	call get_string_length

	stackpop
	ret
