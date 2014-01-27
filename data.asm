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


    sockaddr_in: ;struct
		sin_family dw AF_INET
		sin_port   dw LISTEN_PORT
		sin_addr   dd 0 ;INADDR_ANY
	directory_path dq 0    
	timeval: ;struct
        tv_sec  dq 0
        tv_usec dq 0
    sigaction: ;struct
		sa_handler  dq 0
		sa_flags    dq SA_RESTORER ; also dq, because padding
		sa_restorer dq 0
		sa_mask     dq 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	queue_futex dq 0
	queue_min dq 0
	queue_max dq 0
	queue_start dq 0
	queue_end   dq 0
	signal_futex dq 0

	;Strings
	in_enter db "In Enter:",0x00
	in_enter_len equ $ - in_enter
	in_exit  db "In Exit:", 0x00
	in_exit_len equ $ - in_exit
	new_line db 0x0a
	start_text db "asmttpd - ",ASMTTPD_VERSION,0x00,0x0a
	start_text_len equ $ - start_text
	msg_error     db "An error has occured, exiting",0x00
	msg_error_len equ $ - msg_error
	msg_help      db "Usage: ./asmttpd /path/to/directory",0x00
	msg_help_len  equ $ - msg_help
	msg_using_directory dd "Using Document Root: ",0x00
	msg_using_directory_len equ $ - msg_using_directory
	msg_not_a_directory dd "Error: Specified document root is not a directory",0x00
	msg_not_a_directory_len equ $ - msg_not_a_directory

	;HTTP
	http_ok db "HTTP/1.1 200 OK",0x0d,0x0a
	http_ok_len equ $ - http_ok
	http_not_found db "HTTP/1.1 404 Not Found",0x0d,0x0a
	http_not_found_len equ $ - http_not_found
	server_header db     "Server: asmttpd/",ASMTTPD_VERSION,0x0d,0x0a
	server_header_len equ $ - server_header
	connection_header db "Connection: close",0x0d,0x0a
	connection_header_len equ $ - connection_header
	content_type_html db "Content-Type: text/html",0x0d,0x0a,0x0d,0x0a ;extra because it's the last one
	content_type_html_len equ $ - content_type_html
	content_type_stream db "Content-Type: application/octet-stream",0x0d,0x0a,0x0d,0x0a ;extra because it's the last one
	content_type_stream_len equ $ - content_type_html
