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

print_line: ; rdi = pointer, rsi = length
	stackpush
	call sys_write
	mov rdi, new_line
	mov rsi, 1
	call sys_write
	stackpop
	

get_string_length: ; rdi = pointer, ret rax
	stackpush
	mov rax, -1
	dec rdi
get_string_length_start:
	inc rdi
	inc rax
	cmp BYTE [rdi], 0x0
	jne get_string_length_start
	stackpop
	ret

get_number_of_digits: ; of rdi, ret rax
	stackpush
	push rbx
	push rcx
	
	mov rax, rdi
	mov rbx, 10
	mov rcx, 1 ;count
gnod_cont:
	cmp rax, 10
	jb gnod_ret

	xor rdx,rdx
	div rbx

	inc rcx
	jmp gnod_cont
gnod_ret:
	mov rax, rcx
	
	pop rcx
	pop rbx
	stackpop
	ret

print_rdi:
 
	stackpush
	push rax
	push rbx
	push rcx
	

	call get_number_of_digits
	mov rcx, rax ;

	inc rax ;include NL char in length
	push rax; save length for syscall

	;add lf
	mov rdx, 0xa
	mov [printbuffer+rcx], dl
	dec rcx

	mov rax, rdi ; value to print
	xor rdx, rdx ; zero other half
	mov rbx, 10
	
print_rdi_start:
	xor rdx, rdx ; zero other half
	div rbx      ; divide by 10

	add rdx, 0x30
	mov [printbuffer+rcx], dl
	dec rcx
	cmp rax, 9
	ja print_rdi_start

	add rax, 0x30 ;last digit
	mov [printbuffer+rcx], al

	pop rcx ;restore original length
	
	mov rdi, printbuffer
	mov rsi, rcx
	call sys_write

	pop rcx
	pop rbx
	pop rax
	stackpop
	ret

