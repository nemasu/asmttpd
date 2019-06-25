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

    struc sockaddr_in
        sin_family: resw 1
        sin_port:   resw 1
        sin_addr:   resd 1
    endstruc
    
    sa: istruc sockaddr_in
        at sin_family, dw AF_INET
        at sin_port,   dw 0
        at sin_addr,   dd 0 ;INADDR_ANY
    iend

    request_type dq 0
    request_offset dq 0
    
    timeval: ;struct
        tv_sec  dq 0
        tv_usec dq 0
    sigaction: ;struct
        sa_handler  dq 0
        sa_flags    dq SA_RESTORER ; also dq, because padding
        sa_restorer dq 0
        sa_mask     dq 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    dir_ent_pointer dq 0
    dir_ent_size dq 0
    
    ;Strings
    in_enter db "In Enter:",0x00
    in_enter_len equ $ - in_enter
    in_exit  db "In Exit:", 0x00
    in_exit_len equ $ - in_exit
    new_line db 0x0a
    start_text db "asmttpd - ",ASMTTPD_VERSION,0x0a,0x00
    start_text_len equ $ - start_text
    msg_bind_error     db "Error - Bind() failed. Check if port is in use or you have sufficient privileges.",0x00
    msg_bind_error_len equ $ - msg_bind_error
    msg_error     db "An error has occured, exiting",0x00
    msg_error_len equ $ - msg_error
    msg_help      db "Usage: ./asmttpd /path/to/directory port",0x00
    msg_help_len  equ $ - msg_help
    msg_not_a_directory dd "Error: Specified document root is not a directory",0x00
    msg_not_a_directory_len equ $ - msg_not_a_directory
    msg_request_log db 0x0a,"Request: ",0x00
    msg_request_log_len equ $ - msg_request_log

    header_range_search db "Range: ",0x00
    header_range_search_len equ $ - header_range_search

    location db "Location: ",0x00

    find_bytes_range db "bytes=",0x00
    find_bytes_range_len equ $ - find_bytes_range
    
    filter_prev_dir db "../",0x00
    filter_prev_dir_len equ $ - filter_prev_dir

    crlfx2 db 0x0d,0x0a,0x0d,0x0a,0x00
    crlfx2_len equ $ - crlfx2
    
    crlf db 0x0d,0x0a,0x00
    crlf_len equ $ - crlf

    char_slash db "/",0x00
    char_hyphen db "-",0x00

    ;HTTP
    http_200 db "HTTP/1.1 200 OK",0x0d,0x0a,0x00
    http_200_len equ $ - http_200
    http_206 db "HTTP/1.1 206 Partial Content",0x0d,0x0a,0x00
    http_206_len equ $ - http_206
    http_301 db "HTTP/1.1 301 Moved Permanently",0x0d,0x0a,0x00
    http_301_len equ $ - http_301
    http_404 db "HTTP/1.1 404 Not Found",0x0d,0x0a,0x00
    http_404_len equ $ - http_404
    http_404_text db "I'm sorry, Dave. I'm afraid I can't do that. 404 Not Found",0x00
    http_404_text_len equ $ - http_404_text
    http_400 db "HTTP/1.1 400 Bad Request",0x0d,0x0a,0x00
    http_400_len equ $ - http_400
    http_413 db "HTTP/1.1 413 Request Entity Too Large",0x0d,0x0a,0x00
    http_413_len equ $ - http_413
    http_416 db "HTTP/1.1 416 Requested Range Not Satisfiable",0x0d,0x0a,0x00
    http_416_len equ $ - http_416

    server_header db     "Server: asmttpd/",ASMTTPD_VERSION,0x0d,0x0a,0x00
    server_header_len equ $ - server_header
    
    range_header db "Accept-Ranges: bytes",0x0d,0x0a,0x00
    range_header_len equ $ - range_header

    content_range db "Content-Range: bytes ",0x00
    content_range_len equ $ - content_range  ;Content-Range: bytes 200-1000/3000
    
    content_length db "Content-Length: ",0x00 ;Content-Length: 800
    content_length_len equ $ - content_length

    connection_header db "Connection: close",0x0d,0x0a,0x00
    connection_header_len equ $ - connection_header
    
    content_type db "Content-Type: ",0x00
    content_type_len equ $ - content_type
    
    ;Content-Type
    content_type_html db "text/html",0x0d,0x0a,0x00
    content_type_html_len equ $ - content_type_html
    
    content_type_octet_stream db "application/octet-stream",0x0d,0x0a,0x00
    content_type_octet_stream_len equ $ - content_type_octet_stream
    
    content_type_xhtml db "application/xhtml+xml",0x0d,0x0a,0x00
    content_type_xhtml_len equ $ - content_type_xhtml
    
    content_type_xml db "text/xml",0x0d,0x0a,0x00
    content_type_xml_len equ $ - content_type_xml
    
    content_type_javascript db "application/javascript",0x0d,0x0a,0x00
    content_type_javascript_len equ $ - content_type_javascript
    
    content_type_css db "text/css",0x0d,0x0a,0x00
    content_type_css_len equ $ - content_type_css

    content_type_jpeg db "image/jpeg",0x0d,0x0a,0x00
    content_type_jpeg_len equ $ - content_type_jpeg

    content_type_png db "image/png",0x0d,0x0a,0x00
    content_type_png_len equ $ - content_type_png
    
    content_type_gif db "image/gif",0x0d,0x0a,0x00
    content_type_gif_len equ $ - content_type_gif

    content_type_svg db "image/svg+xml",0x0d,0x0a,0x00
    content_type_svg_len equ $ - content_type_svg

    default_document db "/index.html",0x00
    default_document_len equ $ - default_document
    
    ;Content extension
    extension_html     db ".html",0x00
    extension_htm      db ".htm" ,0x00
    extension_javascript db ".js",  0x00
    extension_css          db ".css", 0x00
    extension_xhtml    db ".xhtml",0x00
    extension_xml      db ".xml",0x00
    extension_gif      db ".gif",0x00
    extension_jpg      db ".jpg",0x00
    extension_jpeg     db ".jpeg",0x00
    extension_png      db ".png",0x00
    extension_svg      db ".svg",0x00

    ; dir listing
    http_200_dir_list_open_h1_tag db "<h1>Index of ",0x00
    http_200_dir_list_close_h1_tag db "</h1>",0x00
    http_dir_entry_open_a_tag_pre db '<p><a href="',0x00
    http_dir_entry_open_a_tag_post db '">',0x00
    http_dir_entry_close_a_tag db '</a></p>',0x00
