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

mutex_leave: 
    stackpush

    mov rax, 1
    mov rdi, 0
    lock cmpxchg [queue_futex], rdi ; 1 -> 0 case
    cmp rax, 1
    je mutex_leave_end

    mov QWORD [queue_futex], 0
    mov rdi, 1
    call sys_futex_wake

    mutex_leave_end:
    stackpop
    ret

mutex_enter:
    stackpush

    mov rax, 0
    mov rdi, 1
    lock cmpxchg [queue_futex], rdi
    cmp rax, 0
    je mutex_enter_end

    mutex_enter_begin:
    cmp rax, 2
    je mutex_enter_wait
    mov rax, 1
    mov rdi, 2
    lock cmpxchg [queue_futex], rdi
    cmp rax, 1
    je mutex_enter_wait
    ;Both tries ( c == 2 || cmpxchg( 1, 2 ) ) failed
    mutex_enter_cont:
    mov rax, 0
    mov rdi, 2
    lock cmpxchg [queue_futex], rdi
    cmp rax, 0
    jne mutex_enter_begin
    jmp mutex_enter_end

    mutex_enter_wait:
    mov rdi, 2
    call sys_futex_wait
    jmp mutex_enter_cont

    mutex_enter_end:
    stackpop
    ret
