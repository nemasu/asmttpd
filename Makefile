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

uname_S := $(shell sh -c 'uname -s 2>/dev/null')

all: main

release: http.asm constants.asm bss.asm data.asm  macros.asm  main.asm  mutex.asm  string.asm  syscall.asm
	yasm -f elf64 -a x86 main.asm -o main.o
	ld main.o -o asmttpd
	strip -s asmttpd

main.o: http.asm constants.asm bss.asm  data.asm  macros.asm  main.asm  mutex.asm  string.asm  syscall.asm
ifeq ($(uname_S),Linux)
		yasm -g dwarf2 -f elf64 -a x86 main.asm -o main.o
endif
ifeq ($(uname_S),Darwin)
	yasm -f macho64 -a x86 main.asm -o main.o
endif

main: main.o
ifeq ($(uname_S),Linux)
	ld main.o -o asmttpd
endif
ifeq ($(uname_S),Darwin)
	ld main.o -o asmttpd -macosx_version_min 10.10 -e _start -lSystem
endif

clean:
	rm -rf main.o asmttpd
