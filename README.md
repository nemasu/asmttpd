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
* 200 for < ~10MB files
* 206 for > ~10MB files. File is split and supports Content-Range header.
* 404 if file not found.
* Content-types: xml, html, xhtml, gif, png, jpeg, css, and js.
  
Planned Features:
* Directory listing.
  
Current Limitations / Known Issues
=======

* Most clients do not use 206 to recieve large files. Need to improve 200 to continuously stream data.  

Installation
=======

Run make or make release for non-debug version.

You will need yasm installed.

Usage
=======

./asmttpd /path/to/web_root

Changes
=======
2014-02-01 : asmttpd - 0.03

* Files are split if too large to fit into buffer. 
* Added 206 responses with Content-Range handling


2014-01-30 : asmttpd - 0.02

* Added xml, xhtml, gif, png, jpeg, css, and javascript content types.
* Changed thread memory size to something reasonable. You can tweak it according to available memory. See comments in main.asm
* Added simple request logging.
* Added removal of '../' in URL.
