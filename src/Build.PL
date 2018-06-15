#!/usr/bin/perl
eval 'exec /usr/bin/env perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

our $cwd;
BEGIN {
    if($0 ne 'Build.PL'){
	eval 'require FindBin';
	chdir("$FindBin::RealBin");
	exec($^X, 'Build.PL')
    }

    ($cwd) = split(/\n/, `pwd`);
}

use lib("$cwd/inc/lib");
use lib("$cwd/../lib");
use lib("$cwd/../perl");
use lib("$cwd/lib");
use lib("$cwd/../perl/lib");

use strict;
use warnings;
use App::Build;

#configure Build
my $build = App::Build->new(
    module_name => 'slucifer',
    dist_author => 'Mark Yandell <Mark Yandell <myandell@genetics.utah.edu>>',
    dist_version_from  => "$cwd/../bin/blasto",
    dist_abstract => 'BLAST wrapper to generate higher sensitivity but lower specificity results (off-road BLAST)',
    license  => 'artistic_2',
    auto_configure_requires => 1, #Module::Build adds self to config_requires
    include_dirs => [], #for included c headers
    requires => {
	'perl'         => '5.8.0',
	'Bio::Root::Version'    => '1.006924',
	#'Other::Module' => '>= 1.2, != 1.5, < 2.0',
    },
    exe_requires => {
        'BLAST+' => 'makeblastdb',
    },
    build_requires => {
    },
    config_requires => {
    },
    recommends => {
    },
    inline_modules => { #additional modules to compile
	#'Other::Module' => '0.01',
    },
    PL_files => {}
);
$build->add_build_element('pl');

$build->create_build_script;
$build->log_info("\n\nThe script 'Build' has been created for you to finish installing Slucifer.\n");
$build->dispatch('status');
