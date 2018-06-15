package Inline::Build;

use strict;
use warnings;
use Config;
use base qw(Module::Build);

__PACKAGE__->add_property(inline_modules => {});

sub new {
    my $class = shift @_;
    my $self = $class->SUPER::new(@_);

    #add/override certain values given the way Inline compiles
    $self->add_build_element('h'); #find header files
    $self->add_to_cleanup('_Inline');
    $self->needs_compiler(1); #can't compile without a compiler. duh
    $self->dynamic_config(1); #ensures that CPAN calls Inline::Build

    #always add primary module to list of inline modules
    #$self->inline_modules()->{$self->module_name} = $self->dist_version;

    return $self;
}

sub ACTION_code {
    my $self = shift;

    #install code into blib for superclass
    $self->SUPER::ACTION_code(@_);

    #now install inline modules into blib
    my $perl = $self->perl;
    my $arch = $self->blib.'/arch';
    my $inline_modules = $self->inline_modules;

    while(my ($module, $version) = each %$inline_modules){
	(my $inl_file = "$module.inl") =~ s/\:\:/\-/g;
	if(!-f $inl_file){
	    my $command = join(' ', $perl => ("-Mblib",
					      "-MInline=NOISY,_INSTALL_",
					      "-M$module",
					      #"-e1",
					      '-e\'my %A = (modinlname => "'.$inl_file.'", module => "'.$module.'"); my %S = (API => \%A); Inline::satisfy_makefile_dep(\%S);\'',
					      "$version",
					      "$arch"));
	    print STDERR $command."\n";
	    my $stat = $self->do_system($command);
	    
	    die "ERROR: $module failed to compile\n" unless($stat);
	}
	$self->add_to_cleanup($inl_file);
    }
}

#hack to get around bug in Module::Build
#otherwise it may ignore changes to config 'cc' and 'ld'
sub config {
    my $self = shift;

    $self->{stash}->{_cbuilder} = undef; #this is hack

    return $self->SUPER::config(@_);
}
