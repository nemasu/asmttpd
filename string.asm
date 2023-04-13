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
    stackpush
    mov rcx, rdx
    inc rcx ; to get null
    cld
    rep movsb 
    stackpop
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
    stackpush
    
    xor r10, r10 ; total length from beginning
    xor r8, r8 ; count from offset

    string_contains_start:
    mov dl, BYTE [rdi]
    cmp dl, 0x00
    je string_contains_ret_no
    cmp dl, BYTE [rsi]
    je string_contains_check
    inc rdi
    inc r10 ; count from base ( total will be r10 + r8 )
    jmp string_contains_start

    string_contains_check:
    inc r8 ; already checked at pos 0
    cmp BYTE [rsi+r8], 0x00
    je string_contains_ret_ok
    mov dl, [rdi+r8]
    cmp dl ,0x00
    je string_contains_ret_no
    cmp dl, [rsi+r8]
    je string_contains_check
    
    inc rdi
    inc r10
    xor r8, r8
    jmp string_contains_start

    string_contains_ret_ok:
    mov rax, r10
    jmp string_contains_ret

    string_contains_ret_no:
    mov rax, -1

    string_contains_ret:
    stackpop
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
    stackpush
    cld
    mov r10, -1
    mov rsi, rdi
get_string_length_start:
    inc r10 
    lodsb
    cmp al, 0x00
    jne get_string_length_start
    mov rax, r10
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

