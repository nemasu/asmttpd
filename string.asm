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
string_itoa:; rdi - buffer, rsi - int
    stackpush
    push rcx
    push rbx

    xchg rdi, rsi
    call get_number_of_digits
    xchg rdi, rsi
    mov rcx, rax ;
    
    ;add null
    mov al, 0x0
    mov [rdi+rcx], al
    dec rcx

    mov rax, rsi ; value to print
    xor rdx, rdx ; zero other half
    mov rbx, 10
    
    string_itoa_start:
    xor rdx, rdx ; zero other half
    div rbx      ; divide by 10

    add rdx, 0x30
    mov [rdi+rcx], dl
    dec rcx
    cmp rax, 9
    ja string_itoa_start

    cmp rcx, 0
    jl string_itoa_done
    add rax, 0x30 ;last digit
    mov [rdi+rcx], al

    string_itoa_done:
    pop rbx
    pop rcx
    stackpop
    ret

string_atoi: ; rdi = string, rax = int
    stackpush
    
    mov r8, 0 ; ;return

    call get_string_length
    mov r10, rax ; length 
    cmp rax, 0
    je string_atoi_ret_empty

    mov r9, 1 ; multiplier
    
    dec r10
    string_atoi_loop:
    xor rbx, rbx
    mov bl, BYTE [rdi+r10]
    sub bl, 0x30   ;get byte, subtract to get real from ascii value
    mov rax, r9    
    mul rbx         ; multiply value by multiplier
    add r8, rax    ; add result to running total
    dec r10        ; next digit
    mov rax, 10 ; multiply r9 ( multiplier ) by 10
    mul r9
    mov r9, rax
    cmp r10, -1
    jne string_atoi_loop
    jmp string_atoi_ret

    string_atoi_ret_empty:
    mov rax, -1
    stackpop
    ret

    string_atoi_ret:
    mov rax, r8
    stackpop
    ret

string_copy: ; rdi = dest, rsi = source, rdx = bytes to copy
    push rdx
	push rcx
	
	inc rdx
	xor eax, eax

string_copy_loop:
	cmp rax, rdx
	je string_copy_return
	
	mov cl, byte [rsi + rax]
	mov byte [rdi + rax], cl
	
	inc rax
	jmp string_copy_loop
	
string_copy_return:
	pop rdx
	pop rcx
	ret

string_concat_int: ;rdi = string being added to, rsi = int to add, ret: new length
    stackpush

    call get_string_length
    add rdi, rax
    call string_itoa

    call get_string_length

    stackpop
    ret

string_concat: ;rdi = string being added to, rsi = string to add, ret: new length
    stackpush
    
    call get_string_length
    add rdi, rax ; Go to end of string
    mov r10, rax
    
    ;Get length of source ie. bytes to copy
    push rdi
    mov rdi, rsi
    call get_string_length
    inc rax ; null
    mov rcx, rax
    add r10, rax
    pop rdi
    
    rep movsb

    mov rax, r10

    stackpop
    ret

string_contains: ;rdi = haystack, rsi = needle, ret = rax: location of string, else -1
    push r9
	push rdx
	push rcx
	push rdi
	push r8
	
	xor r9d, r9d
	xor edx, edx
	
string_contains_start:
	mov cl, byte [rdi]
	mov rax, r9
	test cl, cl
	je string_contains_returnOr
	
	cmp cl, byte [rsi]
	
string_contains_inner:
	je string_contains_maybe
	
	inc r9
	inc rdi
	jmp string_contains_start
	
string_contains_maybe:
	inc rdx
	movzx ecx, byte [rsi + rdx]
	test cl, cl
	je string_contains_return
	
	movsx r8d, byte [rdi + rdx]
	
	test r8b, r8b
	je string_contains_returnOr
	
	cmp r8d, ecx
	jmp string_contains_inner
	
string_contains_returnOr:
	or rax, -1
	
string_contains_return:
	pop r8
	pop rdi
	pop rcx
	pop rdx
	pop r9
	ret


;Removes first instance of string
string_remove: ;rdi = source, rsi = string to remove, ret = 1 for removed, 0 for not found
    stackpush

    mov r9, 0 ; return flag

    call get_string_length
    mov r8, rax ;  r8: source length
    cmp r8, 0 
    mov rax, 0
    jle string_remove_ret ; source string empty?

    push rdi
    mov rdi, rsi
    call get_string_length
    mov r10, rax ; r10: string to remove length
    pop rdi
    cmp r10, 0
    mov rax, 0
    jle string_remove_ret ; string to remove is blank?

    string_remove_start:
    
    call string_contains
    
    cmp rax,-1
    je string_remove_ret
    
    ;Shift source string over
    add rdi, rax
    mov rsi, rdi
    add rsi, r10 ; copying to itself sans found string
    
    cld
    string_remove_do_copy:
    lodsb
    stosb
    cmp al, 0x00
    jne string_remove_do_copy

    mov r9, 1

    string_remove_ret:
    mov rax, r9
    stackpop
    ret

string_ends_with:;rdi = haystack, rsi = needle, ret = rax: 0 false, 1 true
    stackpush

    ;Get length of haystack, store in r8
    call get_string_length
    mov r8, rax

    ;Get length of needle, store in r10
    push rdi
    mov rdi, rsi
    call get_string_length
    mov r10, rax
    pop rdi

    add rdi, r8
    add rsi, r10

    xor rax, rax
    xor rdx, rdx
    
    string_ends_with_loop:
    ;Start from end, dec r10 till 0
    mov dl, BYTE [rdi]
    cmp dl, BYTE [rsi]
    jne string_ends_with_ret
    dec rdi
    dec rsi
    dec r10
    cmp r10, 0
    jne string_ends_with_loop
    mov rax, 1

    string_ends_with_ret:
    stackpop
    ret

string_char_at_reverse: ;rdi = haystack, rsi = count from end, rdx = character(not pointer), ret = rax: 0 false, 1 true
    stackpush
    inc rsi ; include null
    call get_string_length
    add rdi, rax ; go to end
    sub rdi, rsi ; subtract count
    mov rax, 0   ; set return to false
    cmp dl, BYTE [rdi] ; compare rdx(dl)
    jne string_char_at_reverse_ret
    mov rax, 1
    string_char_at_reverse_ret:
    stackpop
    ret

print_line: ; rdi = pointer, rsi = length
    stackpush
    call sys_write
    mov rdi, new_line
    mov rsi, 1
    call sys_write
    stackpop
    ret

get_string_length: ; rdi = pointer, ret rax
    mov rax, -1
get_string_length_loop:
    inc rax
    cmp byte [rdi + rax], 0
    jne get_string_length_loop
    ret


get_number_of_digits: ; of rdi, ret rax
	push rdi
	push rsi
	push rdx
	push rcx
	
	mov rax, rdi
	mov ecx, 1
	mov esi, 10
	
get_number_of_digits_loop:
	cmp rax, 9
	jbe get_number_of_digits_return
	
	xor edx, edx
	div rsi
	inc rcx
	jmp get_number_of_digits_loop
	
get_number_of_digits_return:
	mov rax, rcx
	pop rcx
	pop rdx
	pop rsi
	pop rdi
	ret
