asmttpd
=======

Web server for Linux written in amd64 assembly.

Note: This is very much a work in progress and not ready for production.

Features:
* Multi-threaded via a thread pool
* No libraries required ( only 64-bit Linux )
* Fast

What works:
* Serving files from specified document root.
* 404 if file not found.
* Content-types: xml, html, xhtml, gif, png, jpeg, css, and js.
  
Planned Features:
* Directory listing.
  
Limitations being worked on:
* Files are not read in chuncks, attempting to tranfer a large file will not work.
  
Installation
=======

Run make or make release for non-debug version.

You will need yasm installed.

Usage
=======

./asmttpd /path/to/web_root

Changes
=======

2014-01-30 : asmttpd - 0.02
===

* Added xml, xhtml, gif, png, jpeg, css, and javascript content types.
* Changed thread memory size to something reasonable. You can tweak it according to available memory. See comments in main.asm
* Added simple request logging.
* Added removal of '../' in URL.
