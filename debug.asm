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

;hint, use these with GDB
;set follow-fork-mode child

section .bss
printbuffer:   resb 1024;debug

section .text
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

