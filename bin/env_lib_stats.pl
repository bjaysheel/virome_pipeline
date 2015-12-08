#! /usr/bin/perl

=head1 NAME

   env_lib_stats.pl

=head1 SYNOPSIS

    USAGE: env_lib_stats.pl --server server-name --env dbi [--library libraryId]

=head1 OPTIONS

B<--server,-s>
   Server name that need to be processed.

B<--library,-l>
    Specific libraryId whoes taxonomy info to collect

B<--env,-e>
    Specific environment where this script is executed.  Based on these values
    db connection and file locations are set.  Possible values are
    igs, dbi, ageek or test

B<--help,-h>
   This help message


=head1  DESCRIPTION

    This script will process all libraries on a given server.  Get a
    break down of environmental statistics
        as per
            genesis, sphere, eco-system, exterem, physio_chem, library type
            and various env. library type.

    Counts for each categories are stored in _cnt field, and all sequenceIds
    for each categories are stored in an external file.

=head1  INPUT

    The input is defined with --server which is a domain name only.
      e.g.: calliope (if server name is calliope.dbi.udel.edu)


=head1  OUTPUT

   All counts for each category are stored in "env_statistics" table on the "server"
   given as input.  All sequenceIds for each category are stored in an
   external file, and its location is stored in db.

=head1  CONTACT

  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE

  gen_lib_stats.pl --server calliope --env dbi --library 31

=cut

use strict;
use warnings;
use DBI;
use Switch;
use LIBInfo;
use UTILS_V;
use POSIX qw(ceil floor);
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

BEGIN {
	use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions(
	\%options,   'server|s=s', 'library|b=s', 'env|e=s',
	'input|i=s', 'outdir|o=s', 'log|l=s',     'debug|d=s',
	'help|h'
  )
  || pod2usage();

#### display documentation
if ( $options{'help'} ) {
	pod2usage( { -exitval => 0, -verbose => 2, -output => \*STDERR } );
}

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger(
	'LOG_FILE'  => $logfile,
	'LOG_LEVEL' => $options{'debug'}
);
$logger = $logger->get_logger();
##############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################
my $dbh0;
my $dbh;

my $libinfo = LIBInfo->new();
my $libObject;

my $utils = new UTILS_V;
$utils->set_db_params( $options{env} );

my $file_loc = $options{outdir};

#### make sure everything passed was peachy
&check_parameters( \%options );
##########################################################################
timer();    #call timer to see when process ended.

print "INFO: Start processing.....\n";

my $lib_sel = $dbh0->prepare(q{SELECT name, prefix, server, id FROM library WHERE deleted=0 and server=? ORDER by id});

my $rslt = '';
my @libArray;

if ($options{library} <= 0) {
    $lib_sel->execute($options{server});
    $rslt = $lib_sel->fetchall_arrayref({});

    foreach my $lib (@$rslt) {
        push @libArray, $lib->{'id'};
    }
} else {
    push @libArray, $options{library};
}

foreach my $libId (@libArray) {
	#### loop through each row of the library
	my %lib_feature;
	my $libHash = {
		"LIBRARY"          => {},
		"GENESIS"          => {},
		"SPHERE"           => {},
		"ECO SYSTEM"       => {},
		"EXTREME"          => {},
		"PHYSIO CHEM MODS" => {},
		"LIB TYPE"         => {}
	};

	#### GET THE NUMBER OF ORF COUNT FOR EACH LIBRARY
	my $sequence = $dbh->prepare(
		qq{SELECT distinct b.query_name, b.sequenceId
				 FROM blastp b
				 	inner join
				 	  sequence s on s.id=b.sequenceId
				 WHERE s.libraryId = $libId
				 	and b.e_value <= 0.001
				  	and b.database_name='METAGENOMES' }
	);

	$sequence->execute();
	my $sequenceRSLT = $sequence->fetchall_arrayref({});

	print "INFO: Retrived all sequences for $libObject->{prefix}\n";

	#### loop through all sequence in the given library.
	foreach my $seq (@$sequenceRSLT) {
		#### init struct for each sequence.
		#### each struct is an array of struct for each sequenceId
		#### for example struct of seq_lib_struct will be
		#### sequenceId -> { 'type' => LIBRARY, 'cat' => LIB_PREFIX, 'eval' => EVAL}
		my ( $seq_lib_struct, $eval_sum ) = &bestEvalue( $seq->{sequenceId}, $seq->{query_name} );

		my $curr    = '';
		my $seqHash = {
			"LIBRARY"          => '',
			"GENESIS"          => '',
			"SPHERE"           => '',
			"ECO SYSTEM"       => '',
			"EXTREME"          => '',
			"PHYSIO CHEM MODS" => '',
			"LIB TYPE"         => ''
		};

		#get summary of each sequence.
		foreach my $seqId ( keys %$seq_lib_struct ) {
			my $array      = $seq_lib_struct->{$seqId};
			my $sequenceId = 0;
			my $cat        = '';
			my $link       = '';

			#loop through the hash of each sequence in the library
			#and summarise stats per sequence.
			foreach my $a (@$array) {
				$sequenceId = $a->{'id'};

				#'type' defines genera i.e library, genesis, sphere, eco system
				unless ( $cat =~ /$a->{'type'}/i ) {
					if ( length($link) ) {
						$link =~ s/\^\|\^$//;

						##add sequence summary to hash.
						$seqHash->{$cat} = $link;
					}
					$cat  = $a->{'type'};
					$link = '';
				}

				#eval_sum is a hash containing sum of all evalues per genera
				#$eval_sum is log inverse eval.
				my $weight = log( 1 / $a->{'eval'} ) / $eval_sum->{ $a->{'type'} };

			  	#'cat' contains sub cat of each 'type' i.e: natural, anthropegenic
				$link .= $a->{'cat'} . "=>" . $weight . "^|^";

				#summarized and store for entire library in libHash.
				if (defined $libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'}}) {
					$libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'} }->{'weight'} += $weight;
					$libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'} }->{'id'} .= "," . $a->{'id'};
				}
				else {
					$libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'} }->{'weight'} = $weight;
					$libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'} }->{'id'} = $a->{'id'};
				}

				$libHash->{ $a->{'type'} }->{ $a->{'cat'} }->{ $a->{'from'} }->{'libName'} = $a->{'libName'};
			}

			#link containts concatinated 'cat' for each 'type' per library
			$link =~ s/\^\|\^$//;

			##add sequence summary to hash.
			$seqHash->{$cat} = $link;
		}
	}
	push @{ $lib_feature{ $libId } }, $libHash;

	print "INFO: All sequences processed\n";

	## get summary of each library
	foreach my $libId ( keys %lib_feature ) {
		my $lib_array = $lib_feature{$libId};
		my $link      = '';
		my $curr      = '';

		#loop through each library in the lib array.
		foreach my $category (@$lib_array) {

	   		#loop through all categories/types i.e: eco system, sphere, lib_type etc.
			foreach my $feature ( keys %$category ) {
				my $sub_cat      = $category->{$feature};
				my $total_weight = 0;
				my %print_hash;

				#print feature of given library.
				my $cname   = '';
				my $fprefix = uc $feature;

				$fprefix =~ s/ //ig;
				$cname = $fprefix;

				my $xFile = "${file_loc}/xDocs/${fprefix}_XMLDOC_${libId}.xml";
				my $idFile = "${file_loc}/xDocs/${fprefix}_IDDOC_${libId}.xml";

				open( OUT, ">", $xFile) or die "Cannot open file $xFile to write\n";
				open( IDOUT, ">", $idFile) or die "Cannot open file $idFile to write\n";

				#initialize xml documents.
				print OUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
				print OUT "<root>\n";

				print IDOUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
				print IDOUT "<root>\n";

				my $tagCount = 1;

				foreach my $key ( keys %$sub_cat ) {
					my $hash_val = $category->{$feature}->{$key};

					my $sum_weight = 0;
					my $key_pairs  = '';
					my $id_list    = '';
					my $libName    = '';

					#looop to get sum of all weights in the sub-category
					foreach my $val ( keys %$hash_val ) {
						$sum_weight +=
						  $category->{$feature}->{$key}->{$val}->{'weight'};
					}

					#loop to print sub-category values with percent weight.
					foreach my $val ( keys %$hash_val ) {

						#print from where the eval was take, and weighted sum
						my $tag = $key;
						$tag =~ s/\(.*//gi;
						$tag =~ s/\//_/gi;
						$tag =~ s/ /_/gi;
						$tag =~ s/ $//;
						$tag =~ s/_$//;
						$key_pairs .=
						  "\t\t<$tag NAME=\"$val\" LABEL=\"$val\"" . " VALUE=\""
						  . ceil(
							(
								$category->{$feature}->{$key}->{$val}
								  ->{'weight'} / $sum_weight
							) * 100
						  )
						  . "\""
						  . " TAG=\"TAG_"
						  . $tagCount . "\""
						  . " IDFNAME=\""
						  . $fprefix
						  . "_IDDOC_"
						  . $libId
						  . ".xml\""
						  . " LIBNAME=\""
						  . $category->{$feature}->{$key}->{$val}->{'libName'}
						  . "\"/>\n";

						$id_list .= $category->{$feature}->{$key}->{$val}->{'id'} . ",";
						$libName = $category->{$feature}->{$key}->{$val}->{'libName'};

				  		#print id tag and value in seperate file. no nesting required.
						print IDOUT "<TAG_"
						  . $tagCount
						  . " IDLIST=\"$category->{$feature}->{$key}->{$val}->{'id'}\"/>\n";
						$tagCount++;
					}
					$id_list =~ s/,$//;
					push @{ $print_hash{$key} },
					  {
						'key'      => $key,
						'weight'   => $sum_weight,
						'sub-cat'  => $key_pairs,
						'idList'   => $id_list,
						'libName'  => $libName,
						'tagCount' => $tagCount
					  };
					$total_weight += $sum_weight;
					$tagCount++;
				}

				foreach my $k (%print_hash) {
					my $f = $print_hash{$k};
					foreach my $g (@$f) {
						$g->{key} =~ s/\(.*//gi;
						$g->{key} =~ s/\//_/gi;
						$g->{key} =~ s/ /_/gi;
						$g->{key} =~ s/ $//;
						$g->{key} =~ s/_$//;
						print OUT
						  "<$cname NAME=\"$g->{key}\" LABEL=\"$g->{key}\""
						  . " VALUE=\""
						  . ceil( ( $g->{'weight'} / $total_weight ) * 100 )
						  . "\""
						  .

						  #" IDLIST=\"$g->{idList}\"";
						  " TAG=\"TAG_"
						  . $g->{tagCount} . "\""
						  . " IDFNAME=\""
						  . $fprefix
						  . "_IDDOC_"
						  . $libId
						  . ".xml\"";

						if ( $cname =~ /library/i ) {
							print OUT " LIBNAME=\"$g->{libName}\">\n";
						}
						else {
							print OUT ">\n";
						}

						print OUT $g->{'sub-cat'};
						print OUT "</$cname>\n";

				  		#print id tag and value in seperate file. no nesting required.
						print IDOUT "<TAG_"
						  . $g->{'tagCount'}
						  . " IDLIST=\"$g->{'idList'}\"/>\n";
					}
				}
				print OUT "</root>";
				print IDOUT "</root>";
				close(OUT);
				close(IDOUT);
			}
		}
		print "INFO: Files for library $libId written.\n\n";
	}    #end lib output process
}

# $getlib->finish();
$dbh0->disconnect;
$dbh->disconnect;

timer();    #call timer to see when process ended.
exit(0);

###############################################################################
####  SUBS
###############################################################################

sub check_parameters {
	my $options = shift;

	my $flag = 0;

	# if library list file or library file has been specified
	# get library info. server, id and library name.
	if ( ( defined $options{input} ) && ( length( $options{input} ) ) ) {
		$libObject = $libinfo->getLibFileInfo( $options{input} );
		$flag      = 1;
	}

	# if server is not specifed and library file is not specifed show error
	if ( !$options{server} && !$flag ) {
		pod2usage(
			{
				-exitval => 2,
				-message => "error message",
				-verbose => 1,
				-output  => \*STDERR
			}
		);
		exit(-1);
	}

	# if exec env is not specified show error
	unless ( $options{env} ) {
		pod2usage(
			{
				-exitval => 2,
				-message => "error message",
				-verbose => 1,
				-output  => \*STDERR
			}
		);
		exit(-1);
	}

	# if no library info set library to -1;
	unless ( $options{library} ) {
		$options{library} = -1;
	}

	# if getting info from library file set server and library info.
	if ($flag) {
		$options{library} = $libObject->{id};
		$options{server}  = $libObject->{server};
	}

	system ("mkdir -p $options{outdir}/idFiles");
	system ("mkdir -p $options{outdir}/xDocs");

	$dbh0 = DBI->connect(
		"DBI:mysql:database="
		  . $utils->db_live_name
		  . ";host="
		  . $utils->db_live_host,
		$utils->db_live_user,
		$utils->db_live_pass,
		{ PrintError => 1, RaiseError => 1, AutoCommit => 1 }
	);

	$dbh = DBI->connect(
		"DBI:mysql:database=" . $utils->db_name . ";host=" . $utils->db_host,
		$utils->db_user,
		$utils->db_pass,
		{ PrintError => 1, RaiseError => 1, AutoCommit => 1 }
	);
}

###############################################################################
sub bestEvalue {
	my ( $sequenceId, $query_name ) = @_;

	my %env_feature;
	my %eval_sum = (
		'LIBRARY'   		=> 0,
		'GENESIS'   		=> 0,
		'SPHERE'    		=> 0,
		'ECO SYSTEM' 		=> 0,
		'EXTREME'   		=> 0,
		'PHYSIO CHEM MODS'	=> 0,
		'LIB TYPE'			=> 0
	);

	foreach my $field (
		'lib_prefix', 'genesis',          'sphere', 'ecosystem',
		'extreme',    'physio_chem_mods', 'lib_type'
	  )
	{
		my $blast = $dbh->prepare(qq{SELECT m.$field as field, m.lib_prefix, min(b.e_value) as eval, m.lib_shortname
                                   FROM blastp b
                                   	INNER JOIN
                                   		mgol_library m on LEFT(b.hit_name,3)=m.lib_prefix
                                   WHERE b.sequenceId = $sequenceId
                                   	and b.database_name='METAGENOMES'
                                    and LEFT(hit_name,3) not like LEFT('$query_name',3)
                                    and b.e_value <= 0.001
                                   GROUP BY field, m.lib_prefix
                                   ORDER BY e_value}
		);
		#b.query_name = '$query_name'

		$blast->execute();
		my $blastRSLT = $blast->fetchall_arrayref( {} );

		foreach my $line (@$blastRSLT) {
			$line->{eval} = ( $line->{eval} != 0 ) ? $line->{eval} : 1.0e-255;

			if ( $field eq 'lib_prefix' ) {
				$eval_sum{'LIBRARY'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'LIBRARY',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
			elsif ( $field eq 'genesis' ) {
				$eval_sum{'GENESIS'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'GENESIS',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
			elsif ( $field eq 'sphere' ) {
				$eval_sum{'SPHERE'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'SPHERE',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
			elsif ( $field eq 'ecosystem' ) {
				$eval_sum{'ECO SYSTEM'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'ECO SYSTEM',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
			elsif ( $field eq 'extreme' ) {
				$eval_sum{'EXTREME'} += log( 1 / $line->{eval} );
				$line->{field} =~ s/1/Extreme/gi;
				$line->{field} =~ s/0/Not Extreme/gi;
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'EXTREME',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
			elsif ( $field eq 'physio_chem_mods' ) {
				$eval_sum{'PHYSIO CHEM MODS'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'PHYSIO CHEM MODS',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc( !length( $line->{field} ) )
					? "Not Extreme"
					: $line->{field},
					'eval' => $line->{eval}
				  };
			}
			elsif ( $field eq 'lib_type' ) {
				$eval_sum{'LIB TYPE'} += log( 1 / $line->{eval} );
				push @{ $env_feature{$query_name} },
				  {
					'id'      => $sequenceId,
					'type'    => 'LIB TYPE',
					'from'    => $line->{lib_prefix},
					'libName' => $line->{lib_shortname},
					'cat'     => uc $line->{field},
					'eval'    => $line->{eval}
				  };
			}
		}
	}

	return ( \%env_feature, \%eval_sum );
}

###############################################################################
sub timer {
	my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my (
		$second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings
	  )
	  = localtime();
	  
	my $year    = 1900 + $yearOffset;
	my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	print "Time now: " . $theTime . "\n";
}
