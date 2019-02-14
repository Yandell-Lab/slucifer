#!/usr/bin/perl -w
#######################################################
# Author  :  Aurelie Kapusta
# email   :  4urelie.k@gmail.com
#######################################################
use warnings;
use strict;
use Carp;
use Getopt::Long;
use Data::GUID qw(guid);

my $VERSION = "1.5";
my $SCRIPTNAME = "blasto_parse.pl";
my $CHANGELOG = "
#  v1.0 = 14 Dec 2018
#  v1.1 = 07 Jan 2019
#         Bug fix: query ID was subject ID and the Subject_Name was the query name
#         Added in tab: alignment sequence & cystein count
#  v1.2 = 07 Jan 2019
#         Added superfamily and TPM columns
#  v1.3 = 22 Jan 2019
#         Implemented the --add option
#         Added date
#         Added unique ID (GUID, in base64 representation)
#         Added more cystein counts
#         Added alignment block with escaped \\n and full footer
#  v1.4 = 28 Jan 2019
#         Added query name and query tag (__ separator in the query fasta header)
#  v1.5 = 14 Feb 2019
#         Added space in front of aln string to avoid excel annoyance with the +
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
    -a,--add   (STRING) To add to previous output files, provide the core name 
                        of the previous outputs (<core>.tab and <core>.fasta), 
                        where <core> was what was provided as -i (or -o) of 
                        the previous parsing run.
                        Note that:
                        - outputs for this run only will still be generated, 
                          with the same output core name + the date.
                        - the .tab file is required, the .fasta file is optional
                        
    -f,--fmt   (STRING) Format of the output(s):
                        -f t   #for a tabulated output
                        -f f   #for a fasta file of subject sequences
                        -f b   #for both (Default)
    -o,--out   (STRING) Output core file name
                        Default: folder name of -i if -d is set, 
                        and directory of the file if not
    -l,--log     (BOOL) Print the change log (updates)
    -v           (BOOL) Verbose mode, make the script talks to you
    -v           (BOOL) Print version if only option
    -h,--help    (BOOL) Print this usage\n\n";        
  
#TO DO:

        
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
die "\n -a $ADD set, but $ADD.tab does not exist?\n\n" if ($ADD && ! -e $ADD.".tab");
if ($OUT) {
	die "\n -a $ADD and -o $OUT are the same, please edit\n\n" if ($ADD && $ADD eq $OUT);
} else {
	die "\n -a $ADD and -i $IN are the same: risk that files in $IN are already in the $ADD.tab file...?\n\n" if ($ADD && $DIR && $ADD eq $IN);
}
$IN =~ s/\/$// if ($DIR);
my $WARN;

#-------------------------------------------------------------------------------
#----------------------------------- MAIN --------------------------------------
#-------------------------------------------------------------------------------
print STDERR "\n --- Script $SCRIPTNAME started (v$VERSION)" if ($V);
my ($DATE,$STAMP);
get_timestamp();
print STDERR ", on $DATE\n" if ($V);

#Load previous files
my %IDS = ();
if ($ADD) {
	print STDERR " --- Loading unique IDs of $ADD.tab output\n" if ($V);
	load_previous_ids();
}

#get list of files
print STDERR " --- Loading file list\n" if ($V);
my @FILES = ();
my $OUTFINAL;
get_files();
prep_out();

#Now load
print STDERR " --- Parsing file $IN\n" if (! $DIR && $V);
print STDERR " --- Parsing file(s) from directory $IN\n" if ($DIR && $V);
open (my $FHT, ">>", $OUT.".tab") or confess "     \nERROR - Failed to open to write $OUT.tab $!\n" if ($FMT ne "f");
open (my $FHF, ">", $OUT.".fasta") or confess "     \nERROR - Failed to open to write $OUT.fasta $!\n" if ($FMT ne "t");
foreach my $f (@FILES) {
	chomp $f;
	print STDERR "     - $f\n" if ($DIR && $V);
#	load_footer($f); #implement that later
	parse_blasto($f);
}	
close $FHT if ($FMT ne "f");
close $FHF if ($FMT ne "t");

if ($ADD) {
	`cat $ADD.tab > $OUTFINAL.tab`;
	`cat $OUT.tab | grep -v "^#NOTE" | grep -v "^#UNIQUE" >> $OUTFINAL.tab`;
	`cat $ADD.fasta $OUT.fasta > $OUTFINAL.fasta` if (-e $ADD.".fasta" && -e $OUT.".fasta");
}

print STDERR " --- Output files printed:\n" if ($V);
print STDERR "     -> $OUT.fasta\n" if ($FMT ne "t" && $V);
print STDERR "     -> $OUT.tab\n" if ($FMT ne "s" && $V);
if ($ADD) {
	print STDERR " --- Full output files (--add chosen) printed:\n" if ($V);
	print STDERR "     -> $OUTFINAL.fasta\n" if (-e $ADD.".fasta" && -e $OUT."fasta" && $FMT ne "t" && $V);
	print STDERR "     -> $OUTFINAL.tab\n" if ($V);
}
print STDERR " --- Script done\n" if ($V);
print STDERR "    /!\\ There were warnings. Check log file / STDERR.\n\n" if ($WARN);
print STDERR "\n" if ($V && ! $WARN);
exit;

#-------------------------------------------------------------------------------
#------------------------------- SUBROUTINES -----------------------------------
#-------------------------------------------------------------------------------
sub get_timestamp {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#	my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $year += 1900;
	$mon++;
	$mon = sprintf("%02d",$mon);
	my $time = $hour."h".$min."min".$sec."sec";
	$DATE = $year.".".$mon.".".$mday;
	$STAMP = $DATE."__".$time;
#	print STDERR "$hour h $min min $sec sec - $DATE\n";
	return 1;
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
sub load_previous_ids {
	open (my $fh, "<", $ADD.".tab") or confess "     \nERROR (sub load_previous_ids) Failed to open to read $ADD.tab $!\n";
	while(defined(my $l = <$fh>)) {
 		chomp($l);
		next if ($l !~ /\w/); #blank lines
		next if (substr($l,0,1) eq "#" );
		my @l = split(/\t/,$l);
		$IDS{$l[0]}=1;
	}
	close $fh;
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
	if ($ADD) {
		$OUTFINAL = $OUT;
		$OUT = $OUT."_".$DATE;
	}
	
	#prep header of the tabulated file
	if ($FMT ne "f") {
		open (my $fht, ">", $OUT.".tab") or confess "     \nERROR (sub get_files) Failed to open to write $OUT.tab $!\n";
		print $fht "#NOTE: Q=QUERY; S=SUBJECT; ALN=ALIGNMENT; SEQ=SEQUENCE; SUPERFAM=SUPERFAMILY\n";
		print $fht "#UNIQUE_DB_ID_64bits\tQUERY(BLASTO_FILE)\tQ_NAME\tQ_TAG";
		print $fht "\tDATE_PARSED(YEAR.MONTH.DAY)";
		print $fht "\tS_NAME\tS_SUPERFAM";
		print $fht "\tQ_SEQ\tQ_ALN\tALN_STRING\tS_ALN\tS_SEQ";
		print $fht "\tCYS_Q_NON-ALN\tCYS_Q_ALN\tCYS_IN-ALN\tCYS_S_ALN\tCYS_S_NON-ALN";
		print $fht "\tNOTES_AND_OBSERVATIONS";
		print $fht "\tS_TPM\tQ_LENGTH\tHIT_RANK\tNUM_HSPS";
		print $fht "\tSOLO_E\tSUM_E\tBLAST_E\tTOTAL_BITS\tADJ_BITS";
		print $fht "\tALIGNMENT_FULL";
		print $fht "\tFOOTER_FULL:\n";
		close $fht;
	}
	return 1;
}

#-------------------------------------------------------------------------------
sub get_path {
	my($file) = shift;
	($file =~ /\//)?($file =~ s/(.*)\/.*$/$1/):($file = ".");
	return $file;
}

#-------------------------------------------------------------------------------
sub parse_blasto {
	my $f = shift;
	my $ff = $IN."/".$f if ($DIR);
	my %d = ();
	my $ft = load_footer($ff);
	open (my $fhi, "<", $ff) or confess "     \nERROR (sub parse_blasto) Failed to open to read $ff $!\n";
	while(defined(my $l = <$fhi>)) {
 		chomp($l);
		next if ($l !~ /\w/); #blank lines
		next if (substr($l,0,3) ne "# >" && substr($l,0,1) eq "#"); #commented lines that are not the seq headers
		
		if ($l =~ /FOOTER/) {
			#end of file; print last sequence
			print_stuff(\%d,$f,$ft);
		}
			
		#PARSING
		#new block
		if ($l =~ /^# >.+?$/) {	
			#print previous data if any
			print_stuff(\%d,$f,$ft) if ($d{'qid'});			
			#reset hash
			%d = ();
		}
		#Now load all the info
		$d{'sid'} = $1 if ($l =~ /^# >(.+?)$/);
		$d{'rank'} = $1 if ($l =~ /^I:(.+?)$/);
		$d{'len'} = $1 if ($l =~ /^SBJCT LENGTH:(.+?)$/);
		$d{'hspc'} = $1 if ($l =~ /^NUM HSPS:(.+?)$/);		
		($d{'sloe'},$d{'sume'},$d{'ble'},$d{'tbits'},$d{'adjb'}) = ($1,$2,$3,$4,$5)
			if ($l =~ /^SOLO\sE:([0-9\.e-]+?)\s+SUM\sE:([0-9\.e-]+?)\s+BLAST\sE:([0-9\.e-]+?)\s+TOTAL\sBITS:([0-9\.]+?)\s+ADJ\sBITS:([0-9\.]+?)(\s|$)/);

		#next lines to come is the aln: query is the first one and subject is the second one
		if ($d{'sloe'} && substr($l,0,1) =~ /[0-9]/) {
			my ($seq,$name) = ($1,$2) if ($l =~ /^[0-9]+?\s+?([\w-]+?)\s+?\d+?\s+?(.+?)(\s|$)/);
			if (! $d{'sid_t'} && $d{'qid'}) {
				$d{'sid_t'} = $name; #subject name is the second one
				$d{'aln'} .= $l."\\n";
			}
			if (! $d{'qid'}) { 
				$d{'qid'} = $name; #query name is the first one
				$d{'aln'} = $l."\\n";
			}
			next;
		}
		#grab aln lines, too
		if ($d{'qid'} && ! $d{'sid_t'}) {
			$d{'as'} = $l;
			$d{'as'} =~ s/^\t(.+?)\t.*$/$1/;
			$d{'aln'} .= $l."\\n";
			next;
		}
		#now the rest
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
sub load_footer {
	my $ff = shift;
	my $ft;
	my $fflag;
	open (my $fhi, "<", $ff) or confess "     \nERROR (sub load_footer) Failed to open to read $ff $!\n";
	while(defined(my $l = <$fhi>)) {
		chomp($l);
		$fflag = 1 if ($l =~ /FOOTER/);
		next if (! $fflag || substr($l,0,1) eq "#" || $l =~ /FOOTER/);
		my ($key,$val);
		if ($l =~ /posted_date/ || $l !~ /:/) {
			if ($l =~ /\t/) {
				($key,$val) = split(/\t/,$l);
			} else {
				($key,$val) = split(/\s/,$l);
			}	
			$key =~ s/-//;
		} else {
			($key,$val) = split(/:/,$l);
		}
		if ($ft) {
			$ft.="\t$key:$val";
		} else {
			$ft="$key:$val";
		}
	}
	close $fhi;
	return($ft);
}

#-------------------------------------------------------------------------------
sub print_stuff {
	my $d = shift;
	my $f = shift;
	my $ft = shift;
	if ($FMT ne "f") {
		#get unique ID - need to check on previous output
		my $guid = Data::GUID->guid_base64;
		$guid = Data::GUID->guid_base64 until (! $IDS{$guid});
		$IDS{$guid} = 1;	
 		 		
		#print
		my ($cqa,$csa,$cqna,$csna,$qa,$sa) = get_cysteins($d->{'qs'},$d->{'ss'});
		my $ca = () = $d->{'as'} =~ /C/g;
		my ($sf,$expr) = get_info_from_header($d->{'sid'});
		my ($fn,$ft) = split("__",$f);
		print $FHT "$guid\t$f\t$fn\t$ft";
		print $FHT "\t$DATE";
		print $FHT "\t$d->{'sid'}\t$sf";
		print $FHT "\t$d->{'qs'}\t$qa\t $d->{'as'}\t$sa\t$d->{'ss'}";	
		print $FHT "\t$cqna\t$cqa\t$ca\t$csa\t$csna";
		print $FHT "\t.";
		print $FHT "\t$expr\t$d->{'len'}\t$d->{'rank'}\t$d->{'hspc'}";
		print $FHT "\t$d->{'sloe'}\t$d->{'sume'}\t$d->{'ble'}\t$d->{'tbits'}\t$d->{'adjb'}";
		$d->{'aln'} =~ s/\t/    /g;
		print $FHT "\t$d->{'aln'}";
		#now print footer stuff
		print $FHT "\t$ft";
		print $FHT "\n";
	}
	if ($FMT ne "t") {
		#fasta of subject sequences - not just the HSPs
		print $FHF ">$d->{'qid'}__$d->{'sid'}\t$f\n";
		print $FHF "$d->{'ss'}\n";
	}
	return 1;
}

#-------------------------------------------------------------------------------
sub get_cysteins {
	my $qs = shift;
	my $ss = shift;
	my ($qa,$qna) = ($qs,$qs);
	my ($sa,$sna) = ($ss,$ss);
	$qa =~ s/[\*a-z]//g;
	$sa =~ s/[\*a-z]//g;
	my $cqa = () = $qa =~ /C/g;
	my $csa = () = $sa =~ /C/g;
	my $cqna = () = $qna =~ /c/g;
	my $csna = () = $sna =~ /c/g;	
	return ($cqa,$csa,$cqna,$csna,$qa,$sa); 
}

#-------------------------------------------------------------------------------
sub get_info_from_header {
	my $id = shift;
	#>lcl|3157MUSICUS.TRINITY_SUPFAM:O1_TPM:2098.22_LEN:116
	my ($sf,$expr) = ($1,$2) if ($id =~ /_SUPFAM:(.+?)_TPM:(.+?)_/);
	return ($sf,$expr); 
}

