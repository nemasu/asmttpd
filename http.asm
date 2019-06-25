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

;This writes the text after "Content-Type: " at rsi
detect_content_type: ;rdi - pointer to buffer that contains request, ret - rax: type flag
    stackpush

    mov rsi, extension_htm
    call string_ends_with
    mov r10, CONTENT_TYPE_HTML
    cmp rax, 1
    je detect_content_type_ret

    mov rsi, extension_html
    call string_ends_with
    mov r10, CONTENT_TYPE_HTML 
    cmp rax, 1
    je detect_content_type_ret
    
    mov rsi, extension_css
    call string_ends_with
    mov r10, CONTENT_TYPE_CSS
    cmp rax, 1
    je detect_content_type_ret
    
    mov rsi, extension_javascript
    call string_ends_with
    mov r10, CONTENT_TYPE_JAVASCRIPT
    cmp rax, 1
    je detect_content_type_ret

    mov rsi, extension_xhtml
    call string_ends_with
    mov r10, CONTENT_TYPE_XHTML
    cmp rax, 1
    je detect_content_type_ret

    mov rsi, extension_xml
    call string_ends_with
    mov r10, CONTENT_TYPE_XML
    cmp rax, 1
    je detect_content_type_ret

    mov rsi, extension_gif
    call string_ends_with
    mov r10, CONTENT_TYPE_GIF
    cmp rax, 1
    je detect_content_type_ret
    
    mov rsi, extension_png
    call string_ends_with
    mov r10, CONTENT_TYPE_PNG
    cmp rax, 1
    je detect_content_type_ret
    
    mov rsi, extension_jpeg
    call string_ends_with
    mov r10, CONTENT_TYPE_JPEG
    cmp rax, 1
    je detect_content_type_ret
    
    mov rsi, extension_jpg
    call string_ends_with
    mov r10, CONTENT_TYPE_JPEG
    cmp rax, 1
    je detect_content_type_ret

    mov rsi, extension_svg
    call string_ends_with
    mov r10, CONTENT_TYPE_SVG
    cmp rax, 1
    je detect_content_type_ret

    mov r10, CONTENT_TYPE_OCTET_STREAM ; default to octet-stream
    detect_content_type_ret:
    mov rax, r10
    stackpop
    ret

add_content_type_header: ;rdi - pointer to buffer, rsi - type
    stackpush

    mov r10, rsi

    mov rsi, content_type
    call string_concat

    cmp r10, CONTENT_TYPE_HTML
    je add_response_html
    cmp r10, CONTENT_TYPE_OCTET_STREAM
    je add_response_octet_stream
    cmp r10, CONTENT_TYPE_CSS
    je add_response_css
    cmp r10, CONTENT_TYPE_JAVASCRIPT
    je add_response_javascript
    cmp r10, CONTENT_TYPE_XHTML
    je add_response_xhtml
    cmp r10, CONTENT_TYPE_XML
    je add_response_xml
    cmp r10, CONTENT_TYPE_GIF
    je add_response_gif
    cmp r10, CONTENT_TYPE_PNG
    je add_response_png
    cmp r10, CONTENT_TYPE_JPEG
    je add_response_jpeg
    cmp r10, CONTENT_TYPE_SVG
    je add_response_svg
    
    jmp add_response_octet_stream

    add_response_html:
    mov rsi, content_type_html
    call string_concat
    jmp add_response_cont
    
    add_response_octet_stream:
    mov rsi, content_type_octet_stream
    call string_concat
    jmp add_response_cont
    
    add_response_css:
    mov rsi, content_type_css
    call string_concat
    jmp add_response_cont

    add_response_javascript:
    mov rsi, content_type_javascript
    call string_concat
    jmp add_response_cont

    add_response_xhtml:
    mov rsi, content_type_xhtml
    call string_concat
    jmp add_response_cont

    add_response_xml:
    mov rsi, content_type_xml
    call string_concat
    jmp add_response_cont

    add_response_gif:
    mov rsi, content_type_gif
    call string_concat
    jmp add_response_cont

    add_response_png:
    mov rsi, content_type_png
    call string_concat
    jmp add_response_cont

    add_response_jpeg:
    mov rsi, content_type_jpeg
    call string_concat

    add_response_svg:
    mov rsi, content_type_svg
    call string_concat


    add_response_cont:
    stackpop
    ret

create_httpError_response: ;rdi - pointer, rsi - error code: 400, 416, 413
    stackpush

    cmp rsi, 416
    je create_httpError_response_416
    cmp rsi, 413
    je create_httpError_response_413
    
    ;garbage/default is 400
    mov rsi, http_400
    mov rdx, http_400_len
    call string_copy
    jmp create_httpError_response_cont

    create_httpError_response_416:
    mov rsi, http_416
    mov rdx, http_416_len
    call string_copy
    jmp create_httpError_response_cont

    create_httpError_response_413:
    mov rsi, http_413
    mov rdx, http_413_len
    call string_copy
    jmp create_httpError_response_cont
    
    create_httpError_response_cont:
    mov rsi, server_header
    call string_concat

    mov rsi, connection_header
    call string_concat

    mov rsi, crlfx2
    call string_concat

    call get_string_length

    stackpop
    ret
    

create_http206_response: ;rdi - pointer, rsi - from, rdx - to, r10 - total r9 - type
                         ; looks like Content-Length: `rdx subtract rsi add 1`
                         ;            Content-Range: bytes rsi-rdx/r10
    stackpush

    push rsi
    push rdx

    mov rsi, http_206 ; copy first one
    mov rdx, http_206_len
    call string_copy

    mov rsi, server_header
    call string_concat

    mov rsi, connection_header
    call string_concat

    mov rsi, range_header
    call string_concat
    
    mov rsi, r9
    call add_content_type_header

    mov rsi, content_length
    call string_concat
    
    pop rdx
    pop rsi
    push rsi

    mov r8, rdx
    sub r8, rsi
    inc r8 ; inc cause 'to' is zero based
    mov rsi, r8

    call string_concat_int
    
    mov rsi, crlf
    call string_concat
    
    mov rsi, content_range
    call string_concat
    
    pop rsi
    call string_concat_int

    mov rsi, char_hyphen
    call string_concat

    mov rsi, rdx
    call string_concat_int

    mov rsi, char_slash
    call string_concat

    mov rsi, r10 ; val 
    call string_concat_int
    
    mov rsi, crlfx2
    call string_concat

    call get_string_length
    jmp create_http206_response_ret

    create_http206_response_fail:
    mov rax, 0
    stackpop
    ret

    create_http206_response_ret:
    stackpop
    ret

create_http200_response: ;rdi - pointer to buffer, rsi - type, rdx - length
    stackpush

    push rdx ; save length

    mov r10, rsi ;type
    
    mov rsi, http_200  ;First one we copy
    mov rdx, http_200_len
    call string_copy

    mov rsi, server_header
    call string_concat

    ;mov rsi, connection_header
    ;call string_concat

    mov rsi, range_header
    call string_concat
    
    mov rsi, content_length
    call string_concat

    pop rsi ; length
    call string_concat_int
    
    mov rsi, crlf
    call string_concat

    mov rsi, r10
    call add_content_type_header
    
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

    mov rsi, crlf
    call string_concat

    call get_string_length

    stackpop
    ret

create_http301_response: ;rdi - pointer to buffer
    stackpush

    mov rsi, http_301  ;First one we copy
    mov rdx, http_301_len
    call string_copy

    mov rsi, server_header
    call string_concat

    mov rsi, r10
    call add_content_type_header

    mov rsi, connection_header
    call string_concat

    mov rsi, location
    call string_concat

    ; Remove directory path (web_root) from buffer
    mov rsi, [rbp-16]
    add rsi, r9
    call string_concat
    mov rsi, [directory_path]
    call string_remove

    mov rsi, char_slash
    call string_concat

    mov rsi, crlf
    call string_concat

    call get_string_length

    stackpop
    ret

get_request_type: ;rdi - pointer to buffer, ret = rax: request type
    stackpush

    cld
    mov r10, -1
    mov rsi, rdi
    find_request_string:
    inc r10
    lodsb
    cmp al, 0x20
    jne find_request_string
    mov rax, r10
    add rax, 0x03
    mov [request_offset], rax

    mov rax, REQ_UNK

    check_get:
    cmp byte[rdi+0], 0x47
    jne check_head
    cmp byte[rdi+1], 0x45
    jne check_head
    cmp byte[rdi+2], 0x54
    jne check_head
    mov rax, REQ_GET

    check_head:
    cmp byte[rdi+0], 0x48
    jne request_type_return
    cmp byte[rdi+1], 0x45
    jne request_type_return
    cmp byte[rdi+2], 0x41
    jne request_type_return
    cmp byte[rdi+3], 0x44
    jne request_type_return
    mov rax, REQ_HEAD

    request_type_return:
    stackpop
    ret
