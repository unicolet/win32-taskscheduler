use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Win32::TaskScheduler',
    'VERSION_FROM'	=> 'TaskScheduler.pm',
    'PREREQ_PM'		=> {},
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'TaskScheduler.pm', 
       AUTHOR     => 'Umberto Nicoletti <unicolet@netscape.net>') : ()),
    'LIBS'		=> [' -L"C:/Program Files (x86)/Windows Kits/8.1/Lib/winv6.3/um/x86" -lmstask -luuid'], 
    'DEFINE'		=> '', 
    'INC'		=> '', 
);
