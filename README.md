# win32-taskscheduler

Moved from SourceForge.

This module allows a perl script to manage Scheduled Tasks under Windows NT 4 up to Windows 2003 and perhaps 2008 (R2 excluded).

Windows 2008 introduced a new 2.0 API which makes this module obsolete. The new API can apparently be used
via COM and powershell, so one way or another at least there is a programmatic interface.

I have recently ported (YMMV) this module to dmake (ActiveState switched to mingw+dmake around ActivePerl 5.14).
Earlier ActivePerl versions require Visual C++.

Building with dmake requires that you have the Windows SDK for your windows version. The SDK provides the
libraries files needed by the compiler to resolve the objects and method calls.

Then build with dmake as usual.

More information about Windows TaskScheduler interfaces and versions:

https://msdn.microsoft.com/en-us/library/windows/desktop/aa383614(v=vs.85).aspx
