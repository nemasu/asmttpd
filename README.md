asmttpd
=======

Web server for Linux written in amd64 assembly.

Features:
* Multi-threaded.
* No libraries required ( only 64-bit Linux ).
* Very small binary.
* Quite fast.

What works:
* Serving files from specified document root.
* HEAD requests.
* 200, 206, 404, 400, 413, 416
* Content-types: xml, html, xhtml, gif, png, jpeg, css, js, svg, and octet-stream.
  
Planned Features:
* Directory listing.

Current Limitations / Known Issues
=======
* Sendfile can hang if GET is cancelled.

Installation
=======

Run `make` or `make release` for non-debug version.

You will need `yasm` installed.

Usage
=======

`./asmttpd /path/to/web_root port_number`

Example: `./asmttpd ./web_root 8080`

Changes
=======
2023-04-13 : asmttpd - 0.4.6

* Initial directory listing support.

2021-01-15 : asmttpd - 0.4.5

* string_contains bugfix.

2019-04-22 : asmttpd - 0.4.4

* Added SVG support.

2019-01-24 : asmttpd - 0.4.3

* Added port number as parameter.

2017-10-18 : asmttpd - 0.4.2

* Set REUSEADDR.

2017-10-17 : asmttpd - 0.4.1

* Stack address bug fix.

2016-10-31 : asmttpd - 0.4

* HEAD support.

2014-07-14 : asmttpd - 0.3

* Added default document support.

2014-02-10 : asmttpd - 0.2

* Added 400, 413, 416 responses.
* Fixed header processing bug.

2014-02-07 : asmttpd - 0.1.1

* Fixed 206 max length bug.
* Commented out simple request logging, uncomment in main.asm to enable.

2014-02-06 : asmttpd - 0.1

* Fixed SIGPIPE when transfer is cancelled.
* Added a more useful error on bind failure.
* Fixed 206 size calculation.
* Combined seek & get file size system calls.

2014-02-05 : asmttpd - 0.09

* Issue #8 fix. Crashes on long request paths.

2014-02-04 : asmttpd - 0.08

* Added TCP corking.

2014-02-04 : asmttpd - 0.07

* Removed thread pool after benchmarking, changed to an accept-per-thread model.

2014-02-04 : asmttpd - 0.06

* Worker thread stack corruption bug fix.

2014-02-04 : asmttpd - 0.05

* Changed 200 and 206 implementation to use sendfile system call.
* Got rid of read/write buffer, changed request read buffer to standard 8KB.

2014-02-03 : asmttpd - 0.04

* 200 now streams full amount


2014-02-01 : asmttpd - 0.03

* Files are split if too large to fit into buffer. 
* Added 206 responses with Content-Range handling


2014-01-30 : asmttpd - 0.02

* Added xml, xhtml, gif, png, jpeg, css, and javascript content types.
* Changed thread memory size to something reasonable. You can tweak it according to available memory. See comments in main.asm
* Added simple request logging.
* Added removal of '../' in URL.
