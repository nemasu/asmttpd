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

; d_inode = off + 0
; d_offset = off + 8
; d_reclen = off + 16
; d_name = off + 18
; null byte
; d_type = reclen - 1

; Get total number of getdents entries
get_dir_ents_number: ;ret rax entries
    stackpush

    xor rax, rax
    xor rcx, rcx ; hold offset to current reclen entry
    xor rbx, rbx ; hold total number of entries read
    xor rdx, rdx ; hold total reclen bytes read
    mov rcx, 16 ; point to first reclen offset

    read_dir_ents_reclen:
    mov rsi, [dir_ent_pointer] ; points to linux_dirents buffer
    add rsi, rcx
    lodsw ; ax now contains length of current entry
    inc rbx
    add rcx, rax
    add rdx, rax
    cmp rdx, [dir_ent_size]
    jne read_dir_ents_reclen

    mov rax, rbx
    stackpop
    ret

; Add a list of HTML formatted entries into a buffer
generate_dir_entries: ;rdi - buffer, ret - rax length of string in buffer
    stackpush
    ; Add heading
    mov rsi, http_200_dir_list_open_h1_tag
    call string_concat
    ; Add /<dir_path>/ into heading contents
    mov rsi, [rbp-16]
    add rsi, r9
    call string_concat
    mov rsi, [directory_path]
    call string_remove
    ; Close heading
    mov rsi, http_200_dir_list_close_h1_tag
    call string_concat

    mov rsi, crlf
    call string_concat

    xor rcx, rcx ; hold offset to current reclen entry
    xor rbx, rbx ; hold total number of entries read
    xor rdx, rdx ; hold total reclen bytes read
    mov rcx, 16 ; point to first reclen offset

    read_dir_ents:
    mov rsi, [dir_ent_pointer] ; points to linux_dirents buffer
    add rsi, rcx
    lodsw ; ax now contains length of current entry
    inc rbx
    add rcx, rax
    add rdx, rax

    ; ignore the '.' entry
    cmp word[rsi], 0x002e
    je read_dir_ents_end

    mov rbx, rsi
    push rbx ; save for second time

    push rsi
    mov rsi, http_dir_entry_open_a_tag_pre
    call string_concat
    pop rsi

    call string_concat ; add name, prepend with request dir

    cmp word[rbx], 0x2e2e ; check for '..'
    jne finish_link_tag
    push rsi
    mov rsi, char_slash
    call string_concat
    pop rsi

    finish_link_tag:
    push rsi
    mov rsi, http_dir_entry_open_a_tag_post
    call string_concat
    pop rsi

    pop rbx
    mov rsi, rbx
    call string_concat ; add name again

    push rsi
    mov rsi, http_dir_entry_close_a_tag
    call string_concat
    pop rsi

    read_dir_ents_end:
    cmp rdx, [dir_ent_size]
    jne read_dir_ents

    call get_string_length
    stackpop
    ret
