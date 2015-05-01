use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Win32::TaskScheduler',
    'VERSION_FROM'	=> 'TaskScheduler.pm', # finds $VERSION
    'PREREQ_PM'		=> {},
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'TaskScheduler.pm', 
       AUTHOR     => 'Umberto Nicoletti <unicolet@netscape.net>') : ()),
    'LIBS'		=> ['-L"C:\Program Files\mingw-w64\x86_64-4.9.2-win32-seh-rt_v4-rev2\mingw64\x86_64-w64-mingw32\lib"'], 
    'DEFINE'		=> '', # -TP tells cl to compile all as c++
    'INC'		=> '', # e.g., '-I/usr/include/other'
);
