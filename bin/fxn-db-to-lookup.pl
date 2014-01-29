#!/usr/bin/perl

#eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
#    if 0; # not running under some shell
#BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

=head1 NAME

fxn-db-to-lookup.pl: Create a MLDBM lookup file

=head1 SYNOPSIS

USAGE: fxn-db-to-lookup.pl
	    --table=/tablename
	    --env=/env/where/executing
            --outdir=/output/dir
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--table, -t>
    mysql db table name

B<--env, -e>
    env where executing script igs,dbi,test

B<--outdir, -o>
    Output dir where lookup file will be stored

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to upload info into db.

=head1  INPUT

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use Switch;
use UTILS_V;
use MLDBM 'DB_File';
use Fcntl qw( O_TRUNC O_RDONLY O_RDWR O_CREAT);

#BEGIN {
#  use Ergatis::Logger;
#}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
			  'outdir|o=s',
			  'table|t=s',
			  'env|e=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

#my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
#my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
#                                  'LOG_LEVEL'=>$options{'debug'});
#$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);

my $utils = new UTILS_V;
$utils->set_db_params($options{env});

my $sel_qry='';
my $dbh = '';

if ($options{table} =~ /uniref/i){
  $sel_qry = qq|SELECT u.acc, u.desc, u.organism, u.kegg_acc, u.cog_acc, u.seed_acc, u.aclame_acc, u.phage_seed_acc, 
		      t.domain, t.kingdom, t.phylum, t.n_class, t.n_order, t.family, t.genus, t.species
		FROM uniref u LEFT JOIN taxon t ON u.tax_id=t.tax_id
		ORDER BY u.acc|;

} elsif ($options{table} =~ /kegg/i){
  $sel_qry = qq|SELECT k.realacc, k.desc,
		  k.fxn1,
		  k.fxn2,
		  k.fxn3
	       FROM kegg k
	       ORDER BY k.realacc,k.fxn1,k.fxn2,k.fxn3|;

} elsif ($options{table} =~ /cog/i){
  $sel_qry = qq|SELECT c.realacc,
		  c.fxn1,
		  c.fxn2,
		  c.fxn3
	       FROM cog c
	       ORDER BY c.realacc,c.fxn1,c.fxn2,c.fxn3|;

} elsif ($options{table} =~ /phgseed/i){
  $sel_qry = qq|SELECT p.realacc, p.desc,
                  p.fxn1,
                  p.fxn2,
                  p.subsystem
               FROM phgseed p
               ORDER BY p.realacc,p.fxn1,p.fxn2,p.subsystem|;
} elsif ($options{table} =~ /seed/i){
  $sel_qry = qq|SELECT s.realacc, s.desc,
		  s.fxn1,
		  s.fxn2,
		  s.subsystem
	       FROM seed s
	       ORDER BY s.realacc,s.fxn1,s.fxn2,s.subsystem|;

} elsif ($options{table} =~ /aclame/i){
  $sel_qry = qq|SELECT a.realacc, a.desc,
		    af.chain_id, mc.level, mc.name
	      	FROM  aclame a
		    LEFT JOIN aclamefxn af on a.realacc=af.realacc
		    LEFT JOIN mego_chains mc ON af.chain_id=mc.chain_id
		ORDER BY a.realacc, af.chain_id, mc.level asc|;

} elsif ($options{table} =~ /mgol/i){
  $sel_qry = qq|SELECT	m.seq_type,
			m.lib_type,
			m.na_type,
			m.phys_subst,
			m.org_substr,
			m.ecosystem,
			m.geog_place_name,
			m.country,
			m.lib_shortname,
			m.qryDb,
			m.lib_prefix
		FROM	mgol_library m|;
}


if (length($sel_qry)) {  #table info is passed and expected

	if ($options{table}=~/mgol/i){
		$dbh = DBI->connect("DBI:mysql:database=".$utils->db_name.";host=".$utils->db_host,
   	      $utils->db_user,$utils->db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
	} else {
		$dbh = DBI->connect("DBI:mysql:database=".$utils->u_name.";host=".$utils->db_host,
			$utils->db_user, $utils->db_pass, {PrintError=>1, RaiseError =>1, AutoCommit =>1});
    }

	my $filename = $options{outdir}."/".$options{table}.".ldb";

    #### remove file if it already exists;
    if (-e $filename){
		system("rm $filename");
    }

    ## create the tied hash
    tie(my %info, 'MLDBM', $filename);

	#### get max rows of selected table and iterate through per 10000 rows
	#### due to tmp dir space
	my $max_sql = qq|SELECT count(id) from $options{table}|;
    my $max_sth = $dbh->prepare($max_sql);
    $max_sth->execute();

	my $r=$max_sth->fetchall_arrayref;
	my $max_rows=$r->[0][0];
	my $MAX_LIMIT=10000;

	for (my $i=0; $i<=$max_rows; $i+=$MAX_LIMIT){
		my $qry = $sel_qry;
		
		$qry .= qq| limit $i, $MAX_LIMIT|;
	
		#print"\n\n$qry\n\n";
		
		my $seq_sth = $dbh->prepare($qry);
		$seq_sth->execute();

		my %sel_data;
		my $cnt = 0;

		print "Adding data hash\n";
		if ($options{table} =~ /uniref/i){
			while (my $row = $seq_sth->fetchrow_hashref){
		  		$info{$$row{acc}} = {'acc_data' => [{desc => $$row{desc},
						      kegg_acc => $$row{kegg_acc},
						      cog_acc => $$row{cog_acc},
						      seed_acc => $$row{seed_acc},
						      phgseed_acc => $$row{phage_seed_acc},
						      aclame_acc => $$row{aclame_acc},
						      domain => $$row{domain},
						      kingdom => $$row{kingdom},
						      phylum => $$row{phylum},
						      n_class => $$row{n_class},
						      n_order => $$row{n_order},
						      family => $$row{family},
						      genus => $$row{genus},
						      species => $$row{species},
						      organism => $$row{organism},
						    }]};
	      }
		} elsif ($options{table} =~ /kegg|cog/i) {
	  		while (my $row = $seq_sth->fetchrow_hashref){
				$info{$$row{realacc}} = {'acc_data' => [{desc => (!defined $$row{desc}) ? 'UNKNOWN' : $$row{desc},
						 fxn1 => (!defined $$row{fxn1}) ? 'UNKNOWN' : $$row{fxn1},
						 fxn2 => (!defined $$row{fxn2}) ? 'UNKNOWN' : $$row{fxn2},
						 fxn3 => (!defined $$row{fxn3}) ? 'UNKNOWN' : $$row{fxn3},
						}]};
	      	}
		} elsif ($options{table} =~ /seed/i) {
	  		while (my $row = $seq_sth->fetchrow_hashref){
				$info{$$row{realacc}} = {'acc_data' => [{desc => (!defined $$row{desc}) ? 'UNKNOWN' : $$row{desc},
						 fxn1 => (!defined $$row{fxn1}) ? 'UNKNOWN' : $$row{fxn1},
						 fxn2 => (!defined $$row{fxn2}) ? 'UNKNOWN' : $$row{fxn2},
						 fxn3 => (!defined $$row{subsystem}) ? 'UNKNOWN' : $$row{subsystem},
						}]};
			}
		}
		elsif ($options{table} =~ /phgseed/i){
		    while (my $row = $seq_sth->fetchrow_hashref){
			push (@{$sel_data{$$row{realacc}}}, {desc => (!defined $$row{desc}) ? 'UNKNOWN' : $$row{desc},
							     fxn1 => (!defined $$row{fxn1}) ? 'UNKNOWN' : $$row{fxn1},
							     fxn2 => (!defined $$row{fxn2}) ? 'UNKNOWN' : $$row{fxn2},
							     fxn3 => (!defined $$row{subsystem}) ? 'UNKNOWN' : $$row{subsystem},
			      });
			$cnt++;
			if ($cnt > 10000000){
			    foreach my $acc (keys %sel_data) {
				$info{$acc} = {'acc_data' => $sel_data{$acc}};
			    }
			    $cnt=0;
			    %sel_data = ();
			}
		    }
		}
		elsif ($options{table} =~ /mgol/i) {
		    while (my $row = $seq_sth->fetchrow_hashref){
	    		$info{$$row{lib_prefix}} = {'acc_data' => [{seq_type => (!defined $$row{seq_type}) ? 'UNKNOWN' : $$row{seq_type},
						    lib_type => (!defined $$row{lib_type}) ? 'UNKNOWN' : $$row{lib_type},
						    na_type => (!defined $$row{na_type}) ? 'UNKNOWN' : $$row{na_type},
						    phys_subst => (!defined $$row{phys_subst}) ? 'UNKNOWN' : $$row{phys_subst},
						    org_subst => (!defined $$row{org_subst}) ? 'UNKNOWN' : $$row{org_subst},
						    ecosystem => (!defined $$row{ecosystem}) ? 'UNKNOWN' : $$row{ecosystem},
						    geog_place_name => (!defined $$row{geog_place_name}) ? 'UNKNOWN' : $$row{geog_place_name},
						    country => (!defined $$row{country}) ? 'UNKNOWN' : $$row{country},
						    lib_shortname => (!defined $$row{lib_shortname}) ? 'UNKNOWN' : $$row{lib_shortname},
						    qryDb => (!defined $$row{qryDb}) ? 'UNKNOWN' : $$row{qryDb}
						   }]};
	      	}
		} elsif ($options{table} =~ /aclame/i){
			my $prev_acc = '';
			my $tform = {};
			my $desc = '';
			my $realacc = '';
	  		
	  		while (my $row = $seq_sth->fetchrow_hashref){
	    		if ($realacc ne $$row{realacc}){
	      			if ($realacc ne ''){ #check for the very first time.
						
						$info{$realacc} = {'acc_data' => [{desc => $desc,
														fxn1 => (!defined $tform->{fxn1}) ? 'UNKNOWN' : $tform->{fxn1},
														fxn2 => (!defined $tform->{fxn2}) ? 'UNKNOWN' : $tform->{fxn2},
														fxn3 => (!defined $tform->{fxn3}) ? 'UNKNOWN' : $tform->{fxn3},
														fxn4 => (!defined $tform->{fxn4}) ? 'UNKNOWN' : $tform->{fxn4},
														fxn5 => (!defined $tform->{fxn5}) ? 'UNKNOWN' : $tform->{fxn5},
														fxn6 => (!defined $tform->{fxn6}) ? 'UNKNOWN' : $tform->{fxn6}
													      }]};
						$tform = {};
		  			}
		  		}

				switch ($$row{level}){
					case 1  { $tform->{fxn1} = $$row{name}; }
					case 2  { $tform->{fxn2} = $$row{name}; }
					case 3  { $tform->{fxn3} = $$row{name}; }
					case 4  { $tform->{fxn4} = $$row{name}; }
					case 5  { $tform->{fxn5} = $$row{name}; }
					case 6  { $tform->{fxn6} = $$row{name}; }
	    		} # else swtich stmt
	    
	    		$realacc = $$row{realacc};
	    		$desc = $$row{desc};
	  		} # end of while loop
		} # end else go|aclame stmt

		$seq_sth->finish();
		
	}
	
	untie(%info);
	$dbh->disconnect();
}

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{table} && $options{env} && $options{outdir}) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      #$logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}
