# asmttpd - Web server for Linux written in amd64 assembly. \
Copyright (C) 2014  nemasu <nemasu@gmail.com> \
\
This file is part of asmttpd. \
\
asmttpd is free software: you can redistribute it and/or modify \
it under the terms of the GNU General Public License as published by \
the Free Software Foundation, either version 2 of the License, or \
(at your option) any later version. \
\
asmttpd is distributed in the hope that it will be useful, \
but WITHOUT ANY WARRANTY; without even the implied warranty of \
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \
GNU General Public License for more details. \
\
You should have received a copy of the GNU General Public License \
along with asmttpd.  If not, see <http://www.gnu.org/licenses/>.

all: main

release: http.asm constants.asm bss.asm data.asm  macros.asm  main.asm  mutex.asm  string.asm  syscall.asm dirent.asm
	yasm -f elf64 -a x86 main.asm -o main.o
	ld main.o -o asmttpd
	strip -s asmttpd

main.o: http.asm constants.asm bss.asm  data.asm  macros.asm  main.asm  mutex.asm  string.asm  syscall.asm dirent.asm
	yasm -g dwarf2 -f elf64 -a x86 main.asm -o main.o
main: main.o
	ld main.o -o asmttpd
clean:
	rm -rf main.o asmttpd
