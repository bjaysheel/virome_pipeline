# Sari Khaleel  sari.khalil@gmail.com
# Last modified 6-14-2011 3.00 pm

#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;


# 1st, set the directory for modules to the local directory for this perl script
use FindBin; #to locate the directory of this script 
use lib "$FindBin::Bin/modules";

use manage_commandline_params 1.0;
use Print_output_files 1.0;
use main_subroutines 1.0;

my $program=`basename $0`;
chomp $program;

my $usage =<<USAGE;

USAGE:		
   NOTE: indexes in a sequence are ZER0-BASEED.
   
   This program has two main functions (see below). The main parameters are:
   
    REQUIRED : 
        -i STRING : fastQ input file
		OR
		-il STRING: a .list file that contains the path to the input fastQ file in its first line 
							 
        -o output_prefix : added to the beginning of the output files. You can include a non-existing
                           directory in the prefix path and the program will try to create it.
						   Example: "-o /BAR/foo" results in files (prefixed with "foo_") located at BAR
		  OR
		-od output_dir   : an output directory. This makes all output filenames get prefixed with "KF5_"
						   
I. TO EXTRACT K-MER TABLES FROM (A SAMPLING OF) SEQUENCES IN A FILE:
   --------------------------------------------------------------------
	perl $program (-i file.fq/-il file.list) -tr s_e_l -tl s_e_l (-o output_prefix/-od output_directory)
	     [-minKP minimum_kmer_perc -sp INT -kmp perc -kr_L s_l -kr_R s_l ]
    
	PARAMETERS:
	        -tl s_e_l        : Left (5') Kmer extraction parameters: extract all l-sized kmers (l >= 4) starting at the
                                   bases with  s<= index <=e. -tl 1_5_3 for TAAACCGT yeilds AAA, AAC, ACC, CCG, CGT			
                -tr s_e_l        : Right (3') Kmer extraction parameters: extract all l-sized kmers (l >= 4) starting at the
                                   bases with  s<= index <=e. E.g: -tr 0_1_3 for 5'-AGCTGTAC produces (3'-CAT, 5'-ATG)
        
                -minKP INT       : the minimum kmer percentage limit for a kmer sequence to be added to the kmer table.
                                   Default is (>=) 5 (%)
                -sp INT          : sampling probability for a read in input file. Default is 10%. At sp=10%, each read in 
				                   the input file has a 10% chance of being used for K-mer extraction.

		-kmp INT         : specify the percentage for fuzzy-matching of K-mers. Default is 100% 
		-kr_L s_l        : left kill range. Used to create a list of "sequences to remove" from the target file
		                   by usage #II. If a K-mer (with perc >= minKP) is found in the l-long region starting
                                   at 5'-s, its sequence is added to the "sequences_to_kill_from_SIDENAME.txt" file.
		-kr_R s_l        : right kill range. Used to create a list of "sequences to remove" from the target file
		                   by usage #II. If a K-mer (with perc >= minKP) is found in the l-long region starting
                                   at 3'-s, its sequence is added to the "sequences_to_kill_from_SIDENAME.txt" file.		
	    
		Note that for each side, kill_s must be >= tag_s AND (kill_e + tag_l) must be <= tag_e 
	
	EXAMPLE:
		perl $program -i /path/file -sp 15 -tr 0_10_10 -o ./tags

		This creates ./tags_RIGHT_0-10__10-mer_table.sp-15.kmer, a file that contains a kmer frequency
		table for all unique 10-mer sequences starting from the 3' end 0-10 bases, extracted from 15% of
		sequences.
		
II. TO MATCH K-MERS (FROM A LIST) AGAINST SEQUENCES IN FILE (AND/OR LOAD A KILL-LIST OF SEQUENCES TO TRIM):
    ---------------------------------------------------------------------------------------------------
	To match, 
	  perl $program (-i file.fq/-il file.list) -mr i_l -ml i_l (-o output_prefix/-od output_directory)
	       -lkf left_kmer_table_file -rkf right_kmer_table_file [-mp INT -min_rl]
	To kill 			   
	  perl $program -i file -kr_R s_e -kr_L s_e -o output_prefix 
	                 -kill_lkf left_kmer_table_file -kill_rkf right_kmer_table_file [-mp INT -min_rl]
	
	Note that you CAN do BOTH OF THESE OPERATIONS AT THE SAME TIME 
	
	PARAMETERS:
		-lkf STRING      : left kmer table file, a text file with a list of kmers
		-rkf STRING      : right kmer table file, a text file with a list of kmers
		
		-mr i_l          : number of bases to match against from the right side of the sequence. From the 3'
                                   end, it starts at 3' (i)ndex (0,1,..) and extracts l bases
		-ml i_l          : number of bases to match against from the left side of the sequence. From the 5'
                                   end, it starts at 5' (i)ndex (0,1,..) and extracts l bases
		-kr_L s_e        : kill-range for left side of a read in the input file. If any K-mers from kill_lkf are
		                   matched in this range, the detected K-mer sequence and all sequences to its left will
                                   be removed.
		-kr_R s_e        : same as kr_L, but for left side.			   
		-mp INT          : fuzzy match percentage (for both matching and matching_for_trimming) . Default is 100
		-min_rl INT      : minimum read length allowed for matching (and for a read to be printed to the trimmed
		                   reads file). Default is 100.
	
	EXAMPLE:
		perl $program -i /path/file -o ./tags -mr 0_35 -mp 90
		OR  perl $program -i /path/file -rk ./tags_RIGHT_0-10__10-mer_table.sp-15.kmer -o -mr 0_35 -mp 90 ./tags
	
		This extracts or reads unique right 0-10 10-mers in file, then matches them again the 0-35 right
		(3') bases of file with a match percentage of 90%. The output is saved in the following file:
		./tags_RIGHT_0-10__10-mer.sp-15.matched_vs_0-35.mp-90.match
		
	    The K-mer list file must be similar to the following:
		-------------------------------------------------------------------
		# This a comment. Empty lines or lines starting with # are skipped
		XXXXX	
		XXXXXXXXX
		XXXXXX
		-------------------------------------------------------------------

III. TO DO (I) then (II): USE EXTRACTED K-MER TABLES (FROM READS IN FILE X) TO MATCH THE K-MER SEQUENCES
     IN IT BACK AGAINST READS IN X:
    ----------------------------------------------------------------------------------------------------
	perl $program (-i file.fq/-il file.list) (-o output_prefix/-od output_directory)  -tr s_e_l -tl s_e_l
	     -mr i_l -ml i_l [-kmp INT -minKP minimum_kmer_perc -sp INT -mp INT -kr_R s_l -kr_L s_l -min_rl]
	
USAGE

die $usage unless @ARGV;
my $commandline = "\$ perl $program @ARGV";

# Main Params and their default values
	# Percentages
		my $sampling_perc = 10;
		my $match_perc = 100;
		my $kmer_match_perc = 100; 
		my $min_kmer_perc = 5;
		my $min_read_length = 100;
		
	# Other params
	my ($fQ_inputFile,$input_list_file,$right_kmer_list_file,$left_kmer_list_file,
		$tag_left,$tag_right,     # the vars for -tl s_e_l, tr s_e_l
		$match_left,$match_right, # the vars for -ml i_l -mr i_l
		$kill_left, $kill_right,  # the vars for -kr_R s_e -kr_L s_e
		$opt_sampling_perc, $opt_match_perc,$opt_kmer_match_perc,
		$output_prefix, $output_dir,$opt_min_kmer_perc,
		$right_kill_kmer_list_file, $left_kill_kmer_list_file, $help);

exit if !GetOptions(
		"i=s" => \$fQ_inputFile,
		"il=s" => \$input_list_file,
		"o=s"  => \$output_prefix,
		"od=s" => \$output_dir,
		
		"rkf=s"  => \$right_kmer_list_file,
		"lkf=s"  => \$left_kmer_list_file,
		"kill_rkf=s"  => \$right_kill_kmer_list_file,
		"kill_lkf=s"  => \$left_kill_kmer_list_file,
		
		"tl=s"  => \$tag_left,
		"tr=s"  => \$tag_right,
		"ml=s"  => \$match_left,
		"mr=s"  => \$match_right ,
		"kr_R=s"  => \$kill_right,
		"kr_L=s"  => \$kill_left ,
		
		"sp=i"   => \$opt_sampling_perc,
		"kmp=i"  => \$opt_kmer_match_perc,
		"mp=i"  => \$opt_match_perc,
		"minKP=i" => \$opt_min_kmer_perc,
		"min_rl=i" => \$min_read_length,
		
		"help"  => \$help,
        "h"  => \$help
	   );

die $usage if $help;


# Manage the cases of -il and -od.
	# First, make sure they don't conflict with -i and -o
		die "ERROR: You cannot specify both -i and -il. Choose one.\n" if ($fQ_inputFile && $input_list_file);
		die "ERROR: You cannot specify both -o and -od. Choose one.\n" if ($output_prefix && $output_dir);
	
	# If -il list_file is specified, open list_file and extract the path to the input FQ file
		if ($input_list_file){
			open LIST_FILE, "< $input_list_file";
			my $line = <LIST_FILE>;chomp ($line);
			$fQ_inputFile = $line;
			close LIST_FILE;
		}
		
	# If -od output_dir is specified, set output_prefix to "output_dir/KF5"
		$output_prefix = "$output_dir/KF5" if ($output_dir);

# -----------------------------	 MAIN	-----------------------------
# 1. Manage commandline params:
#		- Validate values,
#		- Modify main params based on opt_params from commandline
	&manage_commandline_params($fQ_inputFile, $left_kmer_list_file, $right_kmer_list_file,
            $opt_sampling_perc, \$sampling_perc,$output_prefix,
            $opt_match_perc, \$match_perc,$opt_min_kmer_perc, \$min_kmer_perc,
			$opt_kmer_match_perc, \$kmer_match_perc,
            $match_left,$match_right,$tag_left,$tag_right,$kill_left,$kill_right,
			$right_kill_kmer_list_file, $left_kill_kmer_list_file);

	print "\n";
	&save_cmd($output_prefix, $commandline);

#  2. Fill the K-hashes with kmers (from list, or from input file), and 
#     Do one (OR BOTH) of the two usages: 
	
	# I. IF WE WANT TO EXTRACT K-MER TABLES FROM FILE:
		if ($tag_left || $tag_right){
			if ($tag_left) {
				# Extract Left-Kmer table (filling the global kmer hash and optionally, the kill_kmer hash),
				# & Print left K-mer table,
				($left_kmer_list_file, $left_kill_kmer_list_file) =
					@{&get_and_print_kmer_tables($tag_left,$kill_left,"left",$fQ_inputFile,$sampling_perc,
											  $min_kmer_perc,$output_prefix,$kmer_match_perc)};
			}
			if ($tag_right){
				# Extract Right-Kmer table (filling the global kmer hash and optionally, the kill_kmer hash),
				# & Print right K-mer table,
				($right_kmer_list_file, $right_kill_kmer_list_file) =
					@{&get_and_print_kmer_tables($tag_right,$kill_right,"right",$fQ_inputFile,$sampling_perc,
											  $min_kmer_perc,$output_prefix,$kmer_match_perc)};
			}
			
		}# end if ($tag_left || $tag_right)

	# II (AND III). IF WE WANT TO MATCH K-MERS (FROM A LIST*) AGAINST SEQUENCES IN FILE:
	# * the list can be implicitly created from Step I
		if ($match_left || $match_right){
			&match_kmers_from_list_against_seqs_n_trim_n_report($output_prefix, $sampling_perc,$fQ_inputFile,$match_perc, $min_kmer_perc,$min_read_length,
														 # Left stuff. Note that the Kmer_list and Kill_Kmer_list files vars can be undefined at this point
														 #             if they were created by Step I (and so tag_left is defined instead). . 
															$tag_left,$left_kmer_list_file,$match_left, $kill_left,$left_kill_kmer_list_file,
														 
														 # Right stuff. Note that the Kmer_list and Kill_Kmer_list files vars can be undefined at this point
														 #             if they were created by Step I (and so tag_right is defined instead). 
															$tag_right,$right_kmer_list_file,$match_right, $kill_right,$right_kill_kmer_list_file
														 );	
		}# end if match left or right

# 4. Exit
	exit;
