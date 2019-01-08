#!/usr/bin/perl -w
#######################################################
# Author  :  Aurelie Kapusta
# email   :  4urelie.k@gmail.com
#######################################################
use warnings;
use strict;
use Carp;
use Getopt::Long;

my $VERSION = "1.2";
my $SCRIPTNAME = "blasto_parse.pl";
my $CHANGELOG = "
#  v1.0 = 14 Dec 2018
#  v1.1 = 07 Jan 2019
#         Bug fix: query ID was subject ID and the Subject_Name was the query name
#         Added in tab: alignment sequence & cystein count
#  v1.2 = 07 Jan 2019
#         Added superfamily and TPM columns
\n";

my $USAGE = "\nUsage [$VERSION]: 
    Usage:
    perl $SCRIPTNAME -i files [-d] [-f format] [-l] [-h] [-v]
	
    Parse blasto output to get hits and/or tabulated output.
    Output files will be:
       <input>.fasta       #fasta file, if -f f or -f b
       <input>.tab         #tabulated text file, if -f t or -f b
	    
    MANDATORY ARGUMENTS:	
    -i,--in    (STRING) blasto output(s); several files can be separated by \",\"
                        or use -d to load ALL files of a directory
                            
    OPTIONAL ARGUMENTS:
    -d,--dir     (BOOL) If -i is a directory. All files in it will be parsed.
    -f,--fmt   (STRING) Format of the output(s):
                        -f t   #for a tabulated output
                        -f f   #for a fasta file of subject sequences
                        -f b   #for both (Default)
    -o,--out   (STRING) Output directory
                        Default: directory of -i
    -l,--log     (BOOL) Print the change log (updates)
    -v           (BOOL) Verbose mode, make the script talks to you
    -v           (BOOL) Print version if only option
    -h,--help    (BOOL) Print this usage\n\n";        
  
#TO DO:
#     -a,--add   (STRING) To add to previous output files. Provide the core name 
#                         (= <input> part) or the previous output. New outputs
#                         will still be generated, with new names.
        
#-------------------------------------------------------------------------------
#------------------------------ LOAD AND CHECK ---------------------------------
#-------------------------------------------------------------------------------
my ($IN,$DIR,$OUT,$ADD,$HELP,$V,$CHLOG);
my $FMT = "b";
GetOptions ('i=s'     => \$IN, 
            'd'       => \$DIR, 
            'f=s'     => \$FMT,
            'o=s'     => \$OUT,
            'a=s'     => \$ADD,
            'l'       => \$CHLOG, 
            'h'       => \$HELP, 
            'v'       => \$V);


#check step to see if mandatory argument is provided + if help/changelog
die "\n Script $SCRIPTNAME version $VERSION\n\n" if (! $IN && ! $HELP && ! $CHLOG && $V);
die $CHANGELOG if ($CHLOG);
die $USAGE if (! $IN || $HELP);
die "\n -i $IN does not exist?\n\n" if ($IN !~ /,/ && ! -e $IN);
$IN =~ s/\/$//;
my $WARN;

#-------------------------------------------------------------------------------
#----------------------------------- MAIN --------------------------------------
#-------------------------------------------------------------------------------
print STDERR "\n --- Script $SCRIPTNAME started (v$VERSION)\n" if ($V);

#get list of files
print STDERR " --- Loading file list\n" if ($V);
my @FILES = ();
get_files();
prep_out();

#Now load
print STDERR " --- Parsing files...\n" if ($V);
open (my $FHT, ">>", $OUT.".tab") or confess "     \nERROR - Failed to open to write $OUT.tab $!\n" if ($FMT ne "f");
open (my $FHF, ">", $OUT.".fasta") or confess "     \nERROR - Failed to open to write $OUT.fasta $!\n" if ($FMT ne "t");
foreach my $f (@FILES) {
	chomp $f;
	print STDERR "     - $f\n" if ($V);
#	load_footer($f); #implement that later
	parse_blasto($f);
}	
close $FHT if ($FMT ne "f");
close $FHF if ($FMT ne "t");


print STDERR " --- Output files printed:\n" if ($V);
print STDERR "     -> $OUT.fasta\n" if ($FMT ne "t" && $V);
print STDERR "     -> $OUT.tab\n" if ($FMT ne "s" && $V);
print STDERR " --- Script done\n" if ($V);
print STDERR "    /!\\ There were warnings. Check log file / STDERR.\n\n" if ($WARN);
print STDERR "\n" if ($V && ! $WARN);
exit;

#-------------------------------------------------------------------------------
#------------------------------- SUBROUTINES -----------------------------------
#----------------------------------------------------------------------------
sub get_path {
	my($file) = shift;
	($file =~ /\//)?($file =~ s/(.*)\/.*$/$1/):($file = ".");
	return $file;
}

#-------------------------------------------------------------------------------
sub get_files {
	if ($DIR) {
		opendir (my $dir, $IN) or confess "     \nERROR (get_files): could not open to read the directory $IN $!\n";
		@FILES = grep { -f "$IN/$_" } readdir($dir);
		@FILES = sort { $a cmp $b } @FILES;
		closedir $dir;
		
		if (! $FILES[0]) {
			print STDERR "     \nERROR: no file in $IN?\n\n" if ($V);
			exit;
		}
	} else {
		if ($IN =~ /,/) {
			@FILES = split(",",$IN);
		} else {
			push(@FILES,$IN);
		}
	}
	return 1;
}

#-------------------------------------------------------------------------------
sub prep_out {
	unless ($OUT) {
		if ($DIR) {
			$OUT = $IN;
		} else {
			$OUT = get_path($IN);
			$OUT = "_" if ($OUT eq ".");	
		}
	}
	
	#prep header of the tabulated file
	if ($FMT ne "f") {
		open (my $fht, ">", $OUT.".tab") or confess "     \nERROR (sub get_files) Failed to open to write $OUT.tab $!\n";
		print $fht "#FILE\tQUERY_ID\tQUERY_SEQ\tQUERY_LENGTH\tHIT_RANK\tNUM_HSPS";
		print $fht "\tSOLO_E\tSUM_E\tBLAST_E\tTOTAL_BITS\tADJ_BITS";
		print $fht "\tSUBJECT_NAME\tSUPERFAMILY\tTPM\tSUBJECT_SEQUENCE\tALIGNMENT\tNUMBER_CYSTEINS";
		print $fht "\n";
		close $fht;
	}
	return 1;
}

#-------------------------------------------------------------------------------
sub parse_blasto {
	my $f = shift;
	my $ff = $IN."/".$f if ($DIR);
	my %d = ();
	open (my $fhi, "<", $ff) or confess "     \nERROR (sub parse_blasto) Failed to open to read $ff $!\n";
	while(defined(my $l = <$fhi>)) {
 		chomp($l);
		next if ($l !~ /\w/); #blank lines
		next if (substr($l,0,3) ne "# >" && substr($l,0,1) eq "#" ); #commented lines that are not the seq headers
			
		if ($l =~ /FOOTER/) {
			#end of file; print last sequence
			print_stuff(\%d,$f);			
			last;
		}
			
		#PARSING
		#new block
		if ($l =~ /^# >.+?$/) {	
			#print previous data if any
			print_stuff(\%d,$f) if ($d{'qid'});			
			#reset hash
			%d = ();
		}
		#Now load all the info
		$d{'id'} = $1 if ($l =~ /^# >(.+?)$/);
		$d{'rank'} = $1 if ($l =~ /^I:(.+?)$/);
		$d{'len'} = $1 if ($l =~ /^SBJCT LENGTH:(.+?)$/);
		$d{'hspc'} = $1 if ($l =~ /^NUM HSPS:(.+?)$/);		
		($d{'sloe'},$d{'sume'},$d{'ble'},$d{'tbits'},$d{'adjb'}) = ($1,$2,$3,$4,$5)
			if ($l =~ /^SOLO\sE:([0-9\.e-]+?)\s+SUM\sE:([0-9\.e-]+?)\s+BLAST\sE:([0-9\.e-]+?)\s+TOTAL\sBITS:([0-9\.]+?)\s+ADJ\sBITS:([0-9\.]+?)(\s|$)/);

		#next lines to come is the aln: query is the first one and subject is the second one
		if ($d{'sloe'} && substr($l,0,1) =~ /[0-9]/) {
			my ($seq,$name) = ($1,$2) if ($l =~ /^[0-9]+?\s+?([\w-]+?)\s+?\d+?\s+?(.+?)(\s|$)/);
			if (! $d{'sid'} && $d{'qid'}) {
				$d{'sid'} = $name; #subject name is the second one
			} 
			if (! $d{'qid'}) { 
				$d{'qid'} = $name; #query name is the first one
			}
		}
		$d{'hspb'} = $1 if ($l =~ /^EXP_HSP_BITS:(.+?)$/);
		$d{'hspl'} = $1 if ($l =~ /^EXP_HSP_LENGTH:(.+?)$/);
		if (substr($l,0,9) eq "QUERY SEQ") {
			$d{'qs_fl'} = 1;
			next;
		}
		if (substr($l,0,7) eq "HIT SEQ") {
			$d{'ss_fl'} = 1;			
			next;
		}
		if ($d{'qs_fl'} && ! $d{'ss_fl'} && $l =~ /^\w/) {
			$d{'qs'}.=$l;
		}
		if ($d{'ss_fl'} && $l =~ /^\w/) {
			$d{'ss'}.=$l;
		}
	}	
	close $fhi;
	return 1;
}

#-------------------------------------------------------------------------------
sub print_stuff {
	my $d = shift;
	my $f = shift;
	if ($FMT ne "f") {
		#get the cysteins
		my ($cys,$aln) = get_cysteins($d->{'ss'});
		my ($sf,$expr) = get_info_from_header($d->{'id'});
		
		print $FHT "$f\t$d->{'qid'}\t$d->{'qs'}\t$d->{'len'}\t$d->{'rank'}\t$d->{'hspc'}";
		print $FHT "\t$d->{'sloe'}\t$d->{'sume'}\t$d->{'ble'}\t$d->{'tbits'}\t$d->{'adjb'}";
		print $FHT "\t$d->{'id'}\t$sf\t$expr\t$d->{'ss'}\t$aln\t$cys";
		print $FHT "\n";
	}
	if ($FMT ne "t") {
		#fasta of subject sequences - not just the HSPs
		print $FHF ">$d->{'qid'}__$d->{'id'}\t$f\n";
		print $FHF "$d->{'ss'}\n";
	}
	return 1;
}

#-------------------------------------------------------------------------------
sub get_cysteins {
	my $seq = shift;
	my $aln = $seq;
	$aln =~ s/[\*a-z]//g;
	my $cys = () = $aln =~ /C/g;
	return ($cys,$aln); 
}

#-------------------------------------------------------------------------------
sub get_info_from_header {
	my $id = shift;
	#>lcl|3157MUSICUS.TRINITY_SUPFAM:O1_TPM:2098.22_LEN:116
	my ($sf,$expr) = ($1,$2) if ($id =~ /_SUPFAM:(.+?)_TPM:(.+?)_/);
	return ($sf,$expr); 
}

