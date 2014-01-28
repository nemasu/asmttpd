asmttpd
=======

Web server for Linux written in amd64 assembly.

This is the inital commit, it is very much a work in progress and not ready for production.

Features:
* Multi-threaded via a thread pool
* No libraries required ( only 64-bit Linux )
* Fast

What works:
* Serving files from specified document root.
* 404 if file not found.
* Content-type text/html for *.htm(l), octet for anything else.
  
Planned Features:
* Directory listing.
* Logs.
  
Limitations being worked on:
* Thread pool does not grow, as such it can become unresponsive if all threads are busy.
* Files are not read in chuncks, attempting to tranfer a large file will not work.
  
Installation
=======

Run make or make release for non-debug version.
You will need yasm installed.

Usage
=======

./asmttpd /path/to/web_root

