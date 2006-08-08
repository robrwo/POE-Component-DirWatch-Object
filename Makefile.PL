use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile
    (
     (MM->can('signature_target') ? (SIGN => 1) : ()),
     NAME                => 'POE::Component::DirWatch::Object',
     AUTHOR              => 'Guillermo Roditi <groditi@cpan.org>',
     VERSION_FROM        => 'lib/POE/Component/DirWatch/Object.pm',
     ABSTRACT_FROM       => 'lib/POE/Component/DirWatch/Object.pm',
     PL_FILES            => {},
     PREREQ_PM => {
		   'Test::More' => 0,
		   'POE' => 0.12,
		   'Moose' => 0.05,
		  },
     dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
     clean               => { FILES => 'POE-Component-DirWatch-Object-*' },
    );
