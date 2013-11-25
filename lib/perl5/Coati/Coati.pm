package Coati::Coati;

use strict;
use Carp;
use Coati::ModulesFactory;
use Coati::Cache::Data;
use Coati::Cache::ReadOnlyMLDBM;
use Coati::Logger;
use File::Basename;
use Coati::Utility;
use base qw(Coati::General);
use base qw(Coati::Modify);
use Coati::TermUsage;
use Coati::IdGenerator;

#################################


my $conf_path;

########################
# INITIATION FUNCTIONS #
########################

sub new {
    my $class = shift;

    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__."API");
    $self->{_schema} = undef;
    $self->{_backend} = undef;
    $self->{_use_cache} = 0;
    $self->{_cache_dir} = "/tmp"; # default cache directory; can be overridden by $ENV{DBCACHE_DIR}

    $self->{_logger}->debug("No schema defined") if ($self->{_logger}->is_debug() && !$self->{_schema});
    $self->{_logger}->debug("No backend defined") if ($self->{_logger}->is_debug() && !$self->{_backend});

    return $self; 
}

sub _init_dbcache{
    my $self = shift;

    my $dbCache = $ENV{DBCACHE};

    # value of '0' or '' or undefined means don't cache
    $self->{_use_cache} = ((defined($dbCache) && ($dbCache !~ /^0?$/)) ? 1 : 0); #Turn on/off database query/results caching
    $self->{_logger}->debug("Value of _use_cache $self->{_use_cache}, dbcache $dbCache, env  $ENV{DBCACHE}") if $self->{_logger}->is_debug;
    
    if($self->{_use_cache}) {

	if($ENV{DBCACHE} eq "file") {

	    my $cacheFileAccess;
	    my $setReadOnlyCache;

	    if (( exists $ENV{_CACHE_FILE_ACCESS}) && (defined($ENV{_CACHE_FILE_ACCESS})) && ($ENV{_CACHE_FILE_ACCESS} ne '')) {

		$cacheFileAccess = $ENV{_CACHE_FILE_ACCESS};
	    }


	    if (( exists $ENV{_SET_READONLY_CACHE}) && 
		(defined($ENV{_SET_READONLY_CACHE})) && 
		($ENV{_SET_READONLY_CACHE} == 1)) {

		$setReadOnlyCache = $ENV{_SET_READONLY_CACHE};
	    }

	    $self->{_logger}->debug("Turning on file based query caching") if $self->{_logger}->is_debug;
	    $self->{_cache_dir} = "$ENV{DBCACHE_DIR}" if (defined($ENV{DBCACHE_DIR}) && ($ENV{DBCACHE_DIR} ne ''));
	    $self->{_backend}->{_data_cache_handler} = new Coati::Cache::Data('MEMORY' =>1,
									      'FILE'   =>1,
									      'SET_READONLY_CACHE' => $setReadOnlyCache,
									      'CACHE_FILE_ACCESS' => $cacheFileAccess,
									      'cachedir'=> $self->{_cache_dir}); #persist query output on disk
	}
	else{
	    $self->{_logger}->debug("Turning on memory based query caching") if $self->{_logger}->is_debug;
	    $self->{_backend}->{_data_cache_handler} = new Coati::Cache::Data('MEMORY'=>1,
									      'FILE'=>0); #persist queries for current instance only
	}
    }
}


sub _init_termusage {

    my $self = shift;

    $self->{_logger}->debug("Instantiating term usage") if $self->{_logger}->is_debug;
    $self->{_termusage} = new Coati::TermUsage();

}

sub _init_idgenerator {
    my $self = shift;
    my $dir = shift;
    $self->{_logger}->debug("Instantiating IdGenerator") if $self->{_logger}->is_debug;

    $self->{_id_generator} = new Coati::IdGenerator( 'id_repository' => $dir); 

    $self->{_id_generator}->set_pool_size( 	 
                                             match => 50, 	 
                                             match_part => 100 	 
                                             );
}

sub get_config_path {
    # the default config file location is the current directory
    my $config_basename = shift;

    my $logger = Coati::Logger::get_logger(__PACKAGE__);

    if (! defined $conf_path) {
        $conf_path = $config_basename;
        my $found = 0; # Flag to denote if the file was found or not

        if (! -e $conf_path) {
            #search for config file in perl search path
            foreach my $inc (@INC) {
                $conf_path = "$inc/conf/$config_basename";
                if (-e $conf_path) {
                    $logger->debug("Found configuration file in search path $conf_path") if $logger->is_debug();
                    $found = 1;
                    last;
                }
            }
        }

        if ($found) {
            $logger->debug("Configuration file location set as $conf_path") if $logger->is_debug();
        } else {
            my $msg = "Can't find $config_basename in current working directory or perl search path";
            $logger->debug($msg);
        }
    } else {
        $logger->debug("Returning path that was already determined beforehand.");
    }

    return $conf_path || '';
}

sub parse_config {
    my ($config_basename, $altconfig) = @_;
    my ($vendor, $schema, $server);

    my $logger = Coati::Logger::get_logger(__PACKAGE__);

    my $supported_dbregex = '^\s*\w+:(BulkSybase:\w+|Sybase:\w+|Mysql:\w+|Postgres:\w+)';
    my $supported_envregex = '\w+=';

    my $confpath = get_config_path($config_basename);

    if (-e $confpath) {
      $logger->debug("Using configuration file $confpath") if($logger->is_debug());
	open CONFIG, "<", "$confpath" or $logger->logdie("Could not open $confpath, stopped");
	my $line;
	while (<CONFIG>) {
	    chomp ($line = $_);             # First, remove the trailing newline.
	    next unless $line =~ m/\w/;     # Skip lines that have just white space.
	    $line =~ s/^\s+//g;             # Remove any leading white space
	    next if $line =~ m/^\#/;        # Skip the line if it's commented.
	    $line =~ s/\s+\#.*$//g;         # Remove any trailing white space / comments.
	    $line =~ s/\s+$//;
	    if ($line =~ m/$supported_dbregex/i) {
		($schema, $vendor, $server) = split (':', $line);
		$logger->debug("Setting backend [schema:$schema, vendor:$vendor, server:$server]") if($logger->is_debug);
	    } 
	    elsif ($line =~ m/$supported_envregex/i){
		my ($key, $value) = ($line =~ /([^=]+)=(.+)/);
		if($key ne "" && $value ne "") {
		    if(exists $ENV{$key}){
			$logger->debug("Skipping conf option for $key.  Using environment variable $key=$ENV{$key}") if($logger->is_debug);
		    }
		    else{
			$ENV{$key} = $value;
			$logger->debug("Set conf option for $key.  $key=$ENV{$key}") if($logger->is_debug);
		    }
		}
	    }
	}
	close CONFIG or $logger->logdie("Could not close the configuration file $confpath, stopped");
    }

    if (defined($altconfig) && ($altconfig ne "")) {
	($schema, $vendor, $server) = split (':', $altconfig);
	$logger->debug("Overriding backend with $altconfig [schema:$schema, vendor:$vendor, server:$server]") if($logger->is_debug);
    }

    return ($schema, $vendor, $server);
};

################################
#^ END # INITIATION FUNCTIONS ^#
##################################################################





########################
#   ALL INPUT_TYPE     #
########################

sub all_GO_term {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_all_GO_term();

    my @fields = ('go_id',
		  'name',
		  'type',
		  'definition',
		  'comment');

    return create_hash(\@fields, $ret);
}

sub all_GO_synonym {
    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_all_GO_synonym();

    my @fields = ('go_id',
		  'synonym');

    return create_hash(\@fields, $ret);
}

sub all_GO_link {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_all_GO_link();
 
    my @fields = ('parent_id',
		  'child_id',
		  'link_type');

    return create_hash(\@fields, $ret);
}

sub all_TI_terms {
    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_all_TI_terms();

    my @fields = ('GO_id',
		  'name',
		  'type',
		  'definition',
		  'date',
		  'assigned_by');
    
    return create_hash(\@fields, $ret);
}

sub all_genome_databases {
    my ($self, @args) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_all_genome_databases();
    
    my @fields = ('db');

    return create_hash(\@fields, $ret);
}

sub all_attribute_types {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_all_attribute_types($db);
    my @fields = ('input_type',
		  'score_types');
    
    return create_hash(\@fields, $ret);
}

sub all_organisms {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_all_organisms($db);
    
    my @fields = ('seq_id',
		  'abbreviation',
		  'common_name',
		  'genus',
		  'species',
		  'organism_id');
    
    return create_hash(\@fields, $ret);

}

sub all_evidence_types {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_all_evidence_types($db);

    my @fields = ('ev_type');
    
    return create_hash(\@fields, $ret);
}

########################
#^ END ALL INPUT_TYPE ^#
##################################################################




########################
#    DB INPUT_TYPE     #
########################

sub db_to_seq_description {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_db_to_seq_description($db);

    my @fields = ('seq_id',
		  'clone_id',
		  'clone_name',
		  'seq_group',
		  'orig_annotation',
		  'tigr_annotation',
		  'status',
		  'length',
		  'final_seq_id',
		  'gb_acc',
		  'assignby',
		  'date',
		  'chromo',
		  'is_public',
		  'prelim');

    return create_hash(\@fields, $ret);
}

sub db_to_organism_name {
    my($self, $db) = @_;
	
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
	
    my $ret = $self->{_backend}->get_db_to_organism_name($db);

    my @fields = ('genus',
				  'species',
				  'common_name');
    
    my $s = create_hash(\@fields, $ret);
    return $s->[0]->{'genus'}." ".$s->[0]->{'species'};
}

sub db_to_seq_names {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_db_to_seq_names($db);
    
    my @fields = ('seq_id',
		  'seq_name',
		  'seq_type',
		  'sequence',
		  'length');

    return create_hash(\@fields, $ret);
}

sub db_to_frameshifts{
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    my %t;
    
    my $ret = $self->{_backend}->get_db_to_frameshifts($db);

    for(my $i=0; $i<@$ret; $i++) {
	$t{$ret->[$i][0]}->{'gene_id'} = $ret->[$i][0];
	$t{$ret->[$i][0]}->{'seq_id'} = $ret->[$i][1];
	$t{$ret->[$i][0]}->{'end5'} = $ret->[$i][2];
	$t{$ret->[$i][0]}->{'end3'} = $ret->[$i][3];

	#############
	# append frameshift types.
	#############
	if(!$t{$ret->[$i][0]}->{'fs_type'}) {
	    $t{$ret->[$i][0]}->{'fs_type'} = $ret->[$i][4];
	}
	else {
	    $t{$ret->[$i][0]}->{'fs_type'} .= ":".$ret->[$i][4];
	}
	
	$t{$ret->[$i][0]}->{'fs_id'} = $ret->[$i][5];
	$t{$ret->[$i][0]}->{'assigndate'} = $ret->[$i][6];
	$t{$ret->[$i][0]}->{'reportdate'} .= $ret->[$i][7];
	$t{$ret->[$i][0]}->{'verifydate'} = $ret->[$i][8];
	$t{$ret->[$i][0]}->{'assignby'} = $ret->[$i][9];
	$t{$ret->[$i][0]}->{'labperson'} = $ret->[$i][10];
	$t{$ret->[$i][0]}->{'reviewby'} = $ret->[$i][11];
	$t{$ret->[$i][0]}->{'curated'} = $ret->[$i][12];
	$t{$ret->[$i][0]}->{'fs_accession'} = $ret->[$i][13];
	$t{$ret->[$i][0]}->{'comment'} = $ret->[$i][14];
	$t{$ret->[$i][0]}->{'gene_name'} = $ret->[$i][15];
    }

    my $j = 0;
    my @s;
    foreach my $gene_id (sort keys %t) {
	my @types;
	push(@types, split(/\:/,$t{$gene_id}->{'fs_type'}));
	foreach my $type (@types) {
	    $s[$j]->{$type} = $type;
	}

	$s[$j]->{'gene_id'} = $t{$gene_id}->{'gene_id'};
	$s[$j]->{'seq_id'} = $t{$gene_id}->{'seq_id'};
	$s[$j]->{'end5'} = $t{$gene_id}->{'end5'};
	$s[$j]->{'end3'} = $t{$gene_id}->{'end3'};
	$s[$j]->{'fs_id'} = $t{$gene_id}->{'fs_id'};
	$s[$j]->{'assigndate'} = $t{$gene_id}->{'assigndate'};
	$s[$j]->{'reportdate'} = $t{$gene_id}->{'reportdate'};
	$s[$j]->{'verifydate'} = $t{$gene_id}->{'verifydate'};
	$s[$j]->{'assignby'} = $t{$gene_id}->{'assignby'};
	$s[$j]->{'labperson'} = $t{$gene_id}->{'labperson'};
	$s[$j]->{'reviewby'} = $t{$gene_id}->{'reviewby'};
	$s[$j]->{'curated'} = $t{$gene_id}->{'curated'};
	$s[$j]->{'fs_accession'} = $t{$gene_id}->{'fs_accession'};
	$s[$j]->{'comment'} = $t{$gene_id}->{'comment'};
	$s[$j]->{'gene_name'} = $t{$gene_id}->{'gene_name'};
	$j++;
    }
    return \@s;
}

sub db_to_roles {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    my $ret = $self->{_backend}->get_db_to_roles($db);

    my @fields = ('gene_id',
		  'role_id',
		  'main_role',
		  'sub_role',
		  'sub_role2',
		  'legacy_gene_id');
    
    return create_hash(\@fields, $ret);
}

sub db_to_GO {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_db_to_GO($db);
 
    my @fields = ('gene_id',
		  'GO_id');

    return create_hash(\@fields, $ret);
}

sub db_to_permissions {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_db_to_permissions($db);
}

sub db_to_gene_features {
    my ($self, $db, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    my $ret = $self->{_backend}->get_db_to_gene_features($db, $feat_type);

    my @fields = ('gene_id',
		  'seq_id',
		  'seq_name',
		  'end5',
		  'end3',
		  'strand',
		  'feat_name',
		  'feat_type',
		  'feat_count');

    return create_hash(\@fields, $ret);
}

sub db_to_tRNAs { 
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
     
    my $ret = $self->{_backend}->get_db_to_tRNAs($db);


    my @fields = ('display_id',
		  'seq_id',
		  'end5',
		  'end3',
		  'gene_id',
		  'value',
		  'residues');


    return create_hash(\@fields, $ret);
}

sub db_to_rRNAs {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_db_to_rRNAs($db);

    my @fields = ('display_id',
		  'seq_id',
		  'end5',
		  'end3',
		  'gene_id',
		  'value',
		  'residues');
    
    return create_hash(\@fields, $ret);
}

sub db_to_snRNAs {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_db_to_snRNAs($db);

    my @fields = ('gene_id',
		  'seq_id',
		  'seq_name',
		  'end5',
		  'end3');

    return create_hash(\@fields, $ret);
}

sub db_to_genes {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_db_to_genes($db);
	
    my @fields = ('gene_id',
				  'sequence',
				  'gene_name',
				  'gene_symbol',
				  'display_id');
    
    return create_hash(\@fields, $ret);
}


sub db_to_SNP_ref_seqs {
    my ($self, $db, $algorithmNames) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    
    
    my $ret = $self->{_backend}->get_db_to_SNP_ref_seqs($db, $algorithmNames);

    my @fields = ('id',
		  'length',
		  'common_name',
		  'genus',
		  'species');

    return create_hash(\@fields, $ret);
}

sub db_to_SNP_query_organisms {
    my ($self, $db, $algorithmNames) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $ret = $self->{_backend}->get_db_to_SNP_query_organisms($db, $algorithmNames);

    my @fields = ('id',
		  'common_name',
		  'genus',
		  'species');

    return create_hash(\@fields, $ret);
}

sub db_to_max_gene_id {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_db_to_max_gene_id($db);
    
    return $ret->[0][0];
}

sub db_to_current_seq_id {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_db_to_current_seq_id($db);

    my @fields = ('seq_id');

    return create_hash(\@fields, $ret);
}

sub db_to_role_breakdown { 
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_db_to_role_breakdown($db);
    
    my @fields = ('role_id',
		  'gene_count',
		  'complete_count');
    
    return create_hash(\@fields, $ret);
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################






#####################
# SEQ_ID INPUT_TYPE #
#####################

sub seq_id_to_length {
    my($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_seq_id_to_length($seq_id, $db);
 
    return $ret->[0][0];
}

sub seq_id_to_description {
    my($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_seq_id_to_description($seq_id, $db);
    
    my @fields = ('clone_id',
		  'clone_name',
		  'seq_group',
		  'orig_annotation',
		  'tigr_annotation',
		  'status',
		  'length',
		  'final_seq_id',
		  'gb_acc',
		  'assignby',
		  'date',
		  'chromo',
		  'is_public',
		  'prelim');
    
    return create_hash(\@fields, $ret);
}

sub seq_id_to_sequence {
    my($self, $seq_id, $start, $stop, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();

    $db = $self->{_db} if (!$db);
    my $ret = $self->{_backend}->get_seq_id_to_sequence($seq_id, $db);
    #
    # Parse out sequence if start/stop coordinates are provided
    my $sequence = $ret->[0][0];
    $start = 1 if($start == 0);
    if ($start && $stop) {
        ($start, $stop) = sort {$a<=>$b} ($start, $stop);
        my $length = $stop - $start + 1;
        $sequence = substr ($sequence, $start - 1, $length);
    }
    return \$sequence;
}

sub seq_id_to_genes {
    my ($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_seq_id_to_genes($seq_id, $db);

    my @fields = ('gene_id',
		  'locus',
		  'com_name',
		  'gene_sym',
		  'ec_num',
		  'seq_id',
		  'end5',
		  'end3',
		  'role_id',
		  'main_role',
		  'sub_role',
		  'complete',
		  'start_edit');

    return create_hash(\@fields, $ret);
}

sub seq_id_to_genome_properties { 	 
     my ($self, $seq_id, $db) = @_; 	 
  	 
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug; 	 
  	 
     my $ret = $self->{_backend}->get_seq_id_to_genome_properties($seq_id, $db); 	 
  	 
     my @fields = ('gene_id', 	 
                   'prop_acc', 	 
                   'property', 	 
                   'state'); 	 
 	 
     return create_hash(\@fields, $ret);	
 }

sub seq_id_to_gene_symbols {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    my $ret = $self->{_backend}->get_seq_id_to_gene_symbols($seq_id, $db);
    
    my @fields = ('gene_id',
		  'gene_symbol');

    return create_hash(\@fields, $ret);
}

sub seq_id_to_ec_numbers {
    my ($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_seq_id_to_ec_numbers($seq_id, $db);
    
    my @fields = ('gene_id',
		  'ec_number');

    return create_hash(\@fields, $ret);
}

sub seq_id_to_gene_features {
    my ($self, $seq_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
        
    my $ret = $self->{_backend}->get_seq_id_to_gene_features($seq_id, $feat_type);

    my @fields = ('gene_id',
		  'seq_id',
		  'seq_name',
		  'end5',
		  'end3',
		  'strand',
		  'feat_name',
		  'feat_count',
		  'feat_type');

    return create_hash(\@fields, $ret);
}

sub seq_id_to_sub_to_final {
    my($self, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_seq_id_to_sub_to_final($seq_id);
    
    my @fields = ('seq_id',
		  'asm_lend',
		  'asm_rend',
		  'sub_asmbl_id',
		  'sub_asm_lend',
		  'sub_asm_rend');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_BER {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_BER($gene_id, $db);

    my @fields = ('id',
		  'accession',
		  'curated',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'score',
		  'pvalue',
		  'per_id',
		  'per_sim');

    return create_hash(\@fields, $ret);
}

sub seq_id_to_roles {
    my($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    my $ret = $self->{_backend}->get_seq_id_to_roles($seq_id, $db);
    
    my @fields = ('gene_id',
		  'role_id',
		  'main_role',
		  'sub_role',
		  'sub_role2',
		  'end5',
		  'end3',
		  'legacy_gene_id');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_paralogs { 
    my($self, $gene_id, $order) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my(@ret, @s, $i);
    
    @ret = $self->{_backend}->get_gene_id_to_paralogs($gene_id, $order);

    for ($i=0; $i<@ret; $i++) {
        $s[$i]->{'align_id'} = $ret[$i][0];
        $s[$i]->{'align_name'} = $ret[$i][1];
        $s[$i]->{'alignment'} = $ret[$i][2];
    }
    return(\@s);
}

sub gene_id_to_CDS {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_CDS($gene_id, $db);

    return $ret->[0][0];
}

sub gene_id_to_partial_gene_toggles {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_partial_gene_toggles($gene_id, $db);

    my @fields = ('five_prime_partial',
		  'three_prime_partial');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_pseudogene_toggle {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_pseudogene_toggle($gene_id, $db);

    my @fields = ('is_pseudogene');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_curated_structure {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_curated_structure($gene_id, $db);

    my @fields = ('curated_structure');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_curated_annotation {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_curated_annotation($gene_id, $db);

    my @fields = ('curated_annotation');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_signalP {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_signalP($gene_id, $db);

    my @fields = ('HMM-position',
		  'HMM-prediction',
		  'HMM-SPprob',
		  'HMM-SAprob',
		  'HMM-cleavprob',
		  'HMM-curated',
		  'id',
		  'C-score',
		  'S-score',
		  'Y-score',
		  's-mean',
		  'cleave_position');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_targetP {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_targetP($gene_id, $db);

    my @fields = ('location',
		  'cmso_scores',
		  'rc_value',
		  'network',
		  'cmso_cutoffs',
		  'curated',
		  'id');

    return create_hash(\@fields, $ret);
}



sub gene_id_to_transmembrane_regions {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_transmembrane_regions($gene_id, $db);

    my @fields = ('coords',
		  'regions',
		  'PredHel',
		  'ExpAA',
		  'First60',
		  'ProbNin');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_molecular_weight {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_molecular_weight($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_seleno_cysteine {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_seleno_cysteine($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_programmed_frameshifts {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_programmed_frameshifts($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_pI {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_pI($gene_id, $db);

    return $ret->[0][0];
}

sub gene_id_to_start_confidence {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_start_confidence($gene_id, $db);
    $ret->[0][0] = "Start confidence not calculated." if(!$ret->[0][0]);

    return $ret->[0][0];
}

sub gene_id_to_outer_membrane_protein {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_outer_membrane_protein($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_lipoprotein {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_lipoprotein($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_secondary_structure {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_secondary_structure($gene_id, $db);
    
    my @fields = ('helix',
		  'strand',
		  'coil');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_feat_score {
    my($self, $gene_id, $score_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_feat_score($gene_id, $score_id);
    
    return $ret->[0][0];
}

sub gene_id_to_att_id {
    my($self, $gene_id, $att_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_att_id($gene_id, $att_type);
    
    return $ret->[0][0];
}

sub gene_id_to_evidence {
    my($self, $gene_id, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_evidence($gene_id, $ev_type, $db);
    
    my @fields = ('id',
		  'ev_type',
		  'accession',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'curated',
		  'date',
		  'assignby',
		  'change_log',
		  'save_history',
		  'method',
		  'per_id',
		  'per_sim',
		  'score',
		  'db',
		  'pvalue',
		  'domain_score',
		  'expect_domain',
		  'total_score',
		  'expect_whole');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_interpro {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_interpro($gene_id);

    my @fields = ('accession');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_prosite {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_prosite($gene_id, $db);
    
    my @fields = ('id',
		  'accession',
		  'score',
		  'curated',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'assignby',
		  'date',
		  'description',
		  'hit_precision',
		  'recall',
		  'pdoc');

    return create_hash(\@fields, $ret);
}

sub prosite_lookup_data {
	my ($self) = @_;
	return $self->{_backend}->get_prosite_lookup_data();
}

sub gene_id_to_prints { 
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->handle_gene_id($gene_id);
    }

    my $ret = $self->{_backend}->get_gene_id_to_prints($gene_id, $db);

    my @fields = ('id',
		  'ev_type',
		  'accession',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'curated',
		  'date',
		  'assignby',
		  'change_log',
		  'save_history',
		  'method');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_prodom { 
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->handle_gene_id($gene_id);
    }

    my $ret = $self->{_backend}->get_gene_id_to_prodom($gene_id, $db);

    my @fields = ('id',
		  'ev_type',
		  'accession',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'curated',
		  'date',
		  'assignby',
		  'change_log',
		  'save_history',
		  'method');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_profiles { 
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->handle_gene_id($gene_id);
    }

    my $ret = $self->{_backend}->get_gene_id_to_profiles($gene_id, $db);

    my @fields = ('id',
		  'ev_type',
		  'accession',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'curated',
		  'date',
		  'assignby',
		  'change_log',
		  'save_history',
		  'method');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_COG { 
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->handle_gene_id($gene_id);
    }
    
    my $ret = $self->{_backend}->get_gene_id_to_COG($gene_id, $db);

    my @fields = ('accession',
		  'rel_end5',
		  'rel_end3');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_autoGO { 
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_evidence2($gene_id, 'autoGO');

    my @fields = ('accession',
		  'rel_end5',
		  'rel_end3',
		  'pvalue');

    return create_hash(\@fields, $ret);    
}

sub gene_id_to_HMMs {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    my $ret = $self->{_backend}->get_gene_id_to_HMMs($gene_id, $db);
    
    my @fields = ('id',
		  'accession',
		  'domain_score',
		  'domain_expect',
		  'total_score',
		  'total_expect',
		  'curated',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'assignby',
		  'date',
		  'm_lend',
		  'm_rend',
		  'trusted_cutoff',
		  'noise_cutoff',
		  'HMM_com_name',
		  'iso_type',
		  'HMM_length',
		  'ec#',
		  'gene_sym',
		  'tc_num',
		  'trusted_cutoff2',
		  'noise_cutoff2',
		  'gathering_cutoff',
		  'gathering_cutoff2');

    return create_hash(\@fields, $ret);    

}

sub gene_id_to_HMM_acc {
    my($self, $gene_id, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_HMM_acc($gene_id, $HMM_acc);
    
    my @fields = ('HMM_acc');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_roles {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_roles($gene_id, $db);

    my @fields = ('role_id',
				  'main_role',
				  'sub_role',
				  'sub_role2');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_ec_numbers {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_ec_numbers($gene_id, $db);

    my @fields = ('ec_num');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_synonyms {
    my($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_gene_id_to_synonyms($gene_id);
    
    my @fields = ('gene_synonym');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_frameshifts {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_frameshifts($gene_id, $db);

    my @fields = ('fs_id',
		  'gene_id',
		  'assignby',
		  'curated',
		  'accession',
		  'assign_date',
		  'att_type',
		  'fs_comment',
		  'cpt_date',
		  'vrf_date',
		  'lab_person',
		  'review_by');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_frameshift_locations {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_frameshift_locations($gene_id, $db);

    my @fields = ('frameshift_id',
		  'frameshift_name',
		  'gene_id',
		  'gene_name',
		  'fmin',
		  'fmax',
          'seqlen',
          'organism_id',
		  'assembly_id',
		  'is_obsolete',
          'is_analysis');

    return create_hash(\@fields, $ret);

}
sub gene_id_to_GO_evidence { 
    my ($self, $gene_id, $GO_id, $id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_gene_id_to_GO_evidence($gene_id, $GO_id, $id, $db);
    
    my @fields = ('ev_code',
		  'evidence',
		  'with_ev');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_GO_suggestions { 
    my($self, $gene_id, $db, $db2) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    #
    # db is optional, and is the source database for gene_id.
    # db2..gene_id has a match to db..gene_id.
    # 
    # A new database connection is required to avoid username 
    # access to omnium.  This is a "security" measure to prevent 
    # unauthorized users from accessing the omnium. 
    #
    # Since we're setting up a new connection, we need the new 
    # username and password.
    $self->{_backend}->{_user} = 'access';
    $self->{_backend}->{_password} = 'access';
    my($olddbh) = $self->{_backend}->{_dbh};
    $self->{_backend}->{_dbh} = $self->{_backend}->_connect;
    
    #
    # Need to get a new database handle into $self->{_backend}, then reset it 
    # back to what it was after getting the data.
    my $ret = $self->{_backend}->get_gene_id_to_GO_suggestions($gene_id, $db, $db2);
    
    #
    # Now restore the original username, password and _dbh;
    $self->{_backend}->{_user} = $self->{_user};
    $self->{_backend}->{_password} = $self->{_password};
    $self->{_backend}->{_dbh} = $olddbh;
    
    my @fields = ('gene_id',
		  'com_name',
		  'p_value',
		  'db');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_fam_id { 
    my($self, $gene_id, $ev_type, $att_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_fam_id($gene_id, $ev_type, $att_type, $db);
    
    my @fields = ('fam_id');

    return create_hash(\@fields, $ret);
}

sub db_to_indel_ref_seqs {
    my ($self, $db) = @_;
    
    $self->_trace if $self->{_debug};
    my (@ret, @s, $i);

    @ret = $self->{_backend}->get_db_to_indel_ref_seqs($db);

    for ($i=0; $i<@ret; $i++) {
        $s[$i]->{'id'} = $ret[$i][0];
        $s[$i]->{'length'} = $ret[$i][1];
        $s[$i]->{'common_name'} = $ret[$i][2];
        $s[$i]->{'genus'} = $ret[$i][3];
        $s[$i]->{'species'} = $ret[$i][4];
    }
    return (\@s);
}

sub db_to_indel_query_organisms {
    my ($self, $db) = @_;
    
    $self->_trace if $self->{_debug};
    my (@ret, @s, $i);

    @ret = $self->{_backend}->get_db_to_indel_query_organisms($db);

    for ($i=0; $i<@ret; $i++) {
        $s[$i]->{'id'} = $ret[$i][0];
        $s[$i]->{'common_name'} = $ret[$i][1];
	$s[$i]->{'genus'} = $ret[$i][2];
	$s[$i]->{'species'} = $ret[$i][3];
    }
    return (\@s);
}

sub gene_id_to_feat_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_feat_id($gene_id);
    
    return $ret->[0][0];
}

sub db_to_gene_count {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_db_to_gene_count($db);

    my @fields = ('seq_id',
		  'gene_count');

    return create_hash(\@fields, $ret);
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################

sub gene_id_to_child_id {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_child_id($gene_id);

    my @fields = ('child_id');
}

sub gene_id_to_transposable_element {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_transposable_element($gene_id);

    my @fields = ('seq_id',
		  'end5',
		  'end3',
		  'feat_type');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_COG_curation {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    my $ret = $self->{_backend}->get_gene_id_to_COG_curation($gene_id, $db);
    
    my @fields = ('COG_id',
		  'db_name',
		  'data_text',
		  'curated',
		  'id');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_primary_descriptions {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_primary_descriptions($gene_id, $db);

    my @fields = ('product_name',
		  'gene_name',
		  'gene_symbol',
		  'ec_number');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_asm_feature_history {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_asm_feature_history($gene_id);
    
    my @fields = ('gene_id',
		  'feat_type',
		  'end5',
		  'end3',
		  'seq_id',
		  'assignby',
		  'prev_mod_date',
		  'last_mod_date',
		  'type');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_gene_attributes {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_gene_attributes($gene_id);

    my @fields = ('gene_id',
		  'att_type',
		  'score_type',
		  'score',
		  'gene_name');
    
    return create_hash(\@fields, $ret);
}

sub synonym_to_gene_id {
    my($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_synonym_to_gene_id($gene_id);
    
    my @fields = ('gene_id');
    
    return create_hash(\@fields, $ret);
}


sub gene_id_to_legacy_data {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_legacy_data($gene_id, $db);
    
    my @fields = ('legacy_gene_id',
		  'legacy_seq_id',
		  'legacy_db');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_protein {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);    

    my $ret = $self->{_backend}->get_gene_id_to_protein($gene_id, $db);

    return $ret->[0][0];
}

sub gene_id_to_protein_id {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_protein_id($gene_id, $db);
    
    my @fields = ('protein_id');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_GO {
    my($self, $gene_id, $db, $GO_id, $assigned_by_exclude) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_GO($gene_id, $db, $GO_id, $assigned_by_exclude);

    my @fields = ('GO_id',
		  'type',
		  'name',
		  'id',
		  'date',
		  'assigned_by',
		  'qualifier');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_transcript {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_transcript($gene_id, $db);
    
    return $ret->[0][0];
}

sub gene_id_to_predictions { 
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_predictions($gene_id, $db);

    my @fields = ('gene_id',
		  'end5',
		  'end3',
		  'gene_type');
    
    return create_hash(\@fields, $ret);
}

sub gene_id_to_nucleotide_evidence {
    my($self, $gene_id, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_nucleotide_evidence($gene_id, $ev_type, $db);
    
    my @fields = ('id',
		  'ev_type',
		  'accession',
		  'end5',
		  'end3',
		  'rel_end5',
		  'rel_end3',
		  'm_lend',
		  'm_rend',
		  'curated',
		  'date',
		  'assignby',
		  'change_log',
		  'save_history',
		  'method',
		  'per_id',
		  'per_sim',
		  'score',
		  'db',
		  'pvalue',
		  'domain_score',
		  'expect_domain',
		  'total_score',
		  'expect_whole');

    return create_hash(\@fields, $ret);
}

sub gene_id_to_exons {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_exons($gene_id, $db);

    my @fields = ('exon_id',
		  'end5',
		  'end3');

    return create_hash(\@fields, $ret);
}

sub handle_gene_id {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    return $self->{_backend}->get_handle_gene_id($gene_id, $db);
}

sub gene_id_to_clusters {
    my($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_gene_id_to_clusters($gene_id, $db);
    
    my @fields = ('cluster_id',
		  'cluster_name');

    return create_hash(\@fields, $ret);
}

############################
#^ END GENE_ID INPUT_TYPE ^#
##################################################################





########################
# ACCESSION INPUT_TYPE #
########################

sub cog_acc_to_COG {
    my ($self, $cog_acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_cog_acc_to_COG($cog_acc);
    my @fields = ('accession',
		  'com_name',
		  'gene_sym');
    return create_hash(\@fields, $ret);
}

sub seq_id_to_transcripts {
    my ($self,$seq_id, $db) = @_;
    
    $db = $self->{_db} if (!$db);
    my $ret = $self->{_backend}->get_seq_id_to_transcripts($seq_id, $db);
    
    my @fields = ('gene_id',
		  'end5',
		  'end3',
		  'strand',
		  'sequence');

    return create_hash(\@fields,$ret);
}

sub seq_id_to_CDS {
    my ($self,$seq_id) = @_;

    my $ret = $self->{_backend}->get_seq_id_to_CDS($seq_id);

    my @fields = ('gene_id',
		  'transcript_id',
		  'cds_id',
		  'protein_id',
		  'end5',
		  'end3',
		  'strand',
		  'sequence',
		  'protein');

    return create_hash(\@fields,$ret);
}

sub seq_id_to_exons {
    my ($self,$seq_id) = @_;

    my $ret = $self->{_backend}->get_seq_id_to_exons($seq_id);

    my @fields = ('gene_id',
		  'transcript_id',
		  'exon_id',
		  'end5',
		  'end3',
		  'strand');

    return create_hash(\@fields,$ret);
}

sub seq_id_to_coverage_data {
    my($self, $seq_id, $data_type, $start, $stop) = @_;
    ($start, $stop) = sort {$a<=>$b} ($start, $stop) if ($start && $stop);

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();

    ##########
    # Start and stop are optional parameters, used to return a sublist
    # of the coverage scores. Start should always be less than stop.
    ##########
    my $ret = $self->{_backend}->get_seq_id_to_coverage_data($seq_id, $data_type, $start, $stop);
    return undef if (!$ret);

    my $coverageScores = [];
    my $nr = scalar(@$ret);
    my $allFmin = $ret->[0][1];
    my $allFmax = $ret->[$nr-1][2];
    my $lastFmax = undef;
    return undef if ($nr == 0);

    for (my $i=0; $i<$nr; $i++) {
	my $data = $ret->[$i][0];
	$data =~ s/^://; # trim unnecessary leading ':'

	my $fmin = $ret->[$i][1];
	my $fmax = $ret->[$i][2];

	if (defined($lastFmax) && ($fmin != $lastFmax)) {
	    # HACK - print error
	    print STDERR "ERR - gap from $lastFmax - $fmin for $seq_id/$data_type/$start/$stop\n";
	}

	my @scores;

	# numeric scores are comma-delimited, but single-letter alphanumeric scores are not
	if ($data =~ /:/) {
	    @scores = split(/:/, $data);
	} else {
	    @scores = split(//, $data);
	}
	
	push(@$coverageScores, @scores);
	$lastFmax = $fmax;
    }

    my $csl = scalar(@$coverageScores);

    # adjust edges of the returned array
    if ($start && $stop) {
	my ($arrayStart, $arrayEnd, $leftPad, $rightPad) = (undef,undef,[],[]);

	my $leftOverhang = $start - $allFmin;
	# trim $leftOverhang from the start of the array
	if ($leftOverhang >= 0) {
	    $arrayStart = $leftOverhang;
	} 
	# add -$leftOverhang unknown scores to the start of the array
	else {
	    $arrayStart = 0;
	    for (my $i = 0; $i < abs($leftOverhang);++$i) {
		push(@$leftPad, '?');
	    }
	}
	
	my $rightOverhang = $allFmax - $stop;
	# trim $rightOverhang from the end of the array
	if ($rightOverhang >= 0) {
	    $arrayEnd = $csl - $rightOverhang;
	}
	else {
	    $arrayEnd = $csl;
	    for (my $i = 0; $i < abs($rightOverhang);++$i) {
		push(@$rightPad, '?');
	    }
	}

	# DEBUG
#	my $lpc = scalar(@$leftPad); my $rpc = scalar(@$rightPad);
#	print STDERR "seq_id_to_coverage_data: lo=$leftOverhang arrayStart=$arrayStart leftPad=$lpc";
#	print STDERR " ro=$rightOverhang arrayEnd=$arrayEnd rightPad=$rpc\n";

	splice(@$coverageScores, 0, $arrayStart);
	splice(@$coverageScores, $arrayEnd - $arrayStart);
	unshift(@$coverageScores, @$leftPad);
	push(@$coverageScores, @$rightPad);

	# DEBUG
#	my $finalLen = scalar(@$coverageScores);
#	my $expectedLen = $stop - $start;
#	if ($finalLen != $expectedLen) {
#	    print STDERR "seq_id_to_coverage_data: ERROR -> expected subseqlen=$expectedLen actual=$finalLen\n";
#	}
    }

    return $coverageScores;
}

sub seq_id_to_new_transposable_element_id {
    my ($self, $seq_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $gene_id = $self->{_backend}->get_seq_id_to_new_transposable_element_id($seq_id, $feat_type);
    return $gene_id;
}

sub seq_id_to_max_gene_id {
    my ($self, $seq_id, $db) = @_;
    $self->_trace if $self->{_debug};
    $db = $self->{_db} if (!$db);
    my $max_gene_id = $self->{_backend}->get_seq_id_to_max_gene_id($seq_id, $db);
    return $max_gene_id;
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################





######################
# EXON_ID INPUT_TYPE #
######################

sub exon_id_to_CDS {
    my($self, $exon_id, $db) = @_;
    
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_exon_id_to_CDS($exon_id, $db);
    
    my @fields = ('CDS_id',
		  'end5',
		  'end3');

    return create_hash(\@fields, $ret);
}

############################
#^ END EXON_ID INPUT_TYPE ^#
##################################################################



###########################
#    GO ID INPUT_TYPE     #
###########################

sub GO_id_to_term {
    my($self, $GO_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_GO_id_to_term($GO_id);
    
    my @fields = ('GO_id',
		  'name',
		  'type',
		  'definition');
    
    return create_hash(\@fields, $ret);
}

sub GO_id_to_child {
    my ($self, $GO_id, $link_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_GO_id_to_child($GO_id, $link_type);

    my @fields = ('parent_id',
		  'child_id',
		  'link_type',
		  'assigned_by',
		  'date');

    return create_hash(\@fields, $ret);
}

sub GO_id_to_parent {
    my ($self, $GO_id, $link_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_GO_id_to_parent($GO_id, $link_type);

    my @fields = ('parent_id',
		  'child_id',
		  'link_type',
		  'assigned_by',
		  'date');

    return create_hash(\@fields, $ret);    
}

sub GO_id_to_new_GO_id {
    my ($self, $GO_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $next_id = $self->{_backend}->get_GO_id_to_new_GO_id($GO_id);

    return $next_id;
}

sub GO_id_to_db_xref {
    my($self, $GO_id, $type) = @_;

    my $ret = $self->{_backend}->get_GO_id_to_db_xref($GO_id, $type);
    
    my @fields = ('acc');

    return create_hash(\@fields, $ret);
}

sub GO_id_to_gene_association { 
    my ($self, $GO_id, $gene_id, $prok_only) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_GO_id_to_gene_association($GO_id, $gene_id, $prok_only);
    
    my @fields = ('gene_id',
		  'GO_id',
		  'db',
		  'gene_name',
		  'type');

    return create_hash(\@fields, $ret);
}

##########################
#^ END GO_ID INPUT_TYPE ^#
##################################################################





########################
# ACCESSION INPUT_TYPE #
########################

sub acc_to_genes {
    my ($self, $acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_acc_to_genes($acc);
    
    my @fields = ('gene_id',
		  'gene_name');
    
    return create_hash(\@fields, $ret);
}

sub acc_to_GO_gene_association {
    my ($self, $acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->acc_to_GO_gene_association($acc);
    
    my @fields = ('db',
		  'gene_id',
		  'gene_symbol',
		  'GO_id',
		  'id',
		  'db_ref',
		  'ev_code',
		  'with_ev');

    return create_hash(\@fields, $ret);    
}

sub HMM_acc_to_GO {
    my($self, $HMM_acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_HMM_acc_to_GO($HMM_acc);
    
    my @fields = ('id',
		  'HMM_acc',
		  'GO_id',
		  'curated',
		  'owner',
		  'mod_date',
		  'comment',
		  'qualifier');

    return create_hash(\@fields, $ret);
}

sub HMM_acc_to_evidence {
    my($self, $HMM_acc, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_HMM_acc_to_evidence($HMM_acc, $db);
    
    my @fields = ('gene_id',
		  'score',
		  'gene_name');

    return create_hash(\@fields, $ret);
}

sub HMM_acc_to_roles { 
    my($self, $HMM_acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_HMM_acc_to_roles($HMM_acc);

    my @fields = ('role_id',
		  'main_role',
		  'sub_role');
    
    return create_hash(\@fields, $ret);
}

sub HMM_acc_to_description {
    my($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_HMM_acc_to_description($HMM_acc);
    
    my @fields = ('HMM_acc',
		  'HMM_type',
		  'HMM_name',
		  'HMM_com_name',
		  'HMM_len',
		  'trusted_cutoff',
		  'noise_cutoff',
		  'HMM_comment',
		  'related_HMM',
		  'author',
		  'entry_date',
		  'mod_date',
		  'std_dev',
		  'ec_num',
		  'avg_score',
		  'std_dev',
		  'iso_type',
		  'private',
		  'gene_sym',
		  'ref_link',
		  'exp_name',
		  'cutoff2',
		  'noise_cutoff2',
		  'iso_id',
		  'id');

    return create_hash(\@fields, $ret);
}

sub HMM_acc_to_features {
    my ($self, $HMM_acc, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_HMM_acc_to_features($HMM_acc, $db);

    my @fields = ('gene_id',
		  'gene_name');

    return create_hash(\@fields, $ret);
}

sub HMM_acc_to_scores {
    my ($self, $HMM_acc, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_HMM_acc_to_scores($HMM_acc, $db);

    my @fields = ('gene_id',
		  'id',
		  'end5',
		  'end3',
		  'm_lend',
		  'm_rend',
		  'score_id',
		  'score');
    
    return create_hash(\@fields, $ret);
}

##############################
#^ END ACCESSION INPUT_TYPE ^#
##################################################################






######################
# ROLE_ID INPUT_TYPE #
######################

sub role_id_to_categories {
    my ($self, $role_id, $main_role, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_role_id_to_categories($role_id, $main_role, $db);
    
    my @fields = ('role_order',
				  'role_id',
				  'main_role',
				  'sub_role');
    
    return create_hash(\@fields, $ret);
}

sub role_id_to_common_notes {
    my($self, $role_id)= @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();
    
    my $ret = $self->{_backend}->get_role_id_to_common_notes($role_id);
    
    my @fields = ('notes',
				  'main_role',
				  'sub_role');

    return create_hash(\@fields, $ret);    
}

sub role_id_to_notes { 
    my($self, $role_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->set_textsize();
    
    my $ret = $self->{_backend}->get_role_id_to_notes($role_id);    
    
    my @fields = ('notes',
		  'main_role',
		  'sub_role');

    return create_hash(\@fields, $ret);    
}

sub role_id_to_genes {
    my($self, $role_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_role_id_to_genes($role_id, $db);

    my @fields = ('gene_id');

    return create_hash(\@fields, $ret);
}

sub role_id_to_gene_descriptions {
    my($self, $role_id, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $seq_id = "ISCURRENT" if(!$seq_id);
    
    my $ret = $self->{_backend}->get_role_id_to_gene_descriptions($role_id, $seq_id);

    my @fields = ('gene_id', 
		  'locus', 
		  'gene_name', 
		  'gene_sym', 
		  'complete', 
		  'auto_annotate', 
		  'ec_num', 
		  'asmbl_id', 
		  'end5', 
		  'end3');
    
    return create_hash(\@fields, $ret);
}

sub seq_id_to_CDS_loci {
    my ($self,$seq_id) = @_;
    my ($ret, @s, $i);

    $ret = $self->{_backend}->get_seq_id_to_CDS_loci($seq_id);

    my @fields = ('cds_id',
		  'locus_id',
		  'version',
		  'description');

    return create_hash(\@fields,$ret);
}

sub seq_id_to_SNPs {
    my($self,$refseq_id,$queryseq_id,$query_org_ids,$analysis_ids) = @_;
    my $ret = $self->{_backend}->get_seq_id_to_SNPs($refseq_id,$queryseq_id,$query_org_ids,$analysis_ids);

    my @fields = ('snp_id',
		  'ref_pos',
		  'ref_strand',
		  'query_seq_id',
		  'query_pos',
		  'query_strand',
		  );

    return create_hash(\@fields,$ret);
}

sub ref_seq_posn_to_SNPs{
    my($self,$refseq_id,$refseq_posn,$analysis_ids) = @_;
    my $ret = $self->{_backend}->get_ref_seq_posn_to_SNPs($refseq_id,$refseq_posn,$analysis_ids);

    my @fields = ('snp_id',
		  'ref_pos',
		  'ref_strand',
		  'query_seq_id',
		  'query_pos',
		  'query_endpos',
		  'query_strand'
		  );

    return create_hash(\@fields,$ret);
}

sub seq_id_to_indels{
    my($self,$refseq_id,$queryseq_id,$query_org_ids,$analysis_ids) = @_;
    my $ret = $self->{_backend}->get_seq_id_to_indels($refseq_id,$queryseq_id,$query_org_ids,$analysis_ids);

    my @fields = ('indel_id',
		  'type',
		  'ref_asmbl',
		  'ref_fmin',
		  'ref_fmax',
		  'ref_strand',
		  'ref_info',
		  'query_asmbl',
		  'query_fmin',
		  'query_fmax',
		  'query_strand',
		  'query_info',
		  );

    return create_hash(\@fields,$ret);
}

sub indel_id_to_indel_info{
    my($self,$indel_id) = @_;
    my $ret = $self->{_backend}->get_indel_id_to_indel_info($indel_id);

    my @fields = ('indel_id',
		  'type',
		  'ref_asmbl',
		  'ref_fmin',
		  'ref_fmax',
		  'ref_strand',
		  'ref_info',
		  'query_asmbl',
		  'query_fmin',
		  'query_fmax',
		  'query_strand',
		  'query_info',
		  );

    return create_hash(\@fields,$ret);
}

#if site_loc overlaps multiple genes, this code will only report one overlapping transcript/CDS
sub seq_id_coordinates_to_coding_info{
    my($self,$seq_id,$coordinates,$seq_id_to_num_genes) = @_;
    my @sitelocs;
    my @sitelocsrev;

    my $seq_length = $self->seq_id_to_length($seq_id);
    # JC: have to specify this method explicitly, because somebody has apparently overridden
    # it in CMR.pm, but using a different signature and return type (!)
    my $residues = Coati::Coati::seq_id_to_sequence($self, $seq_id);

    # hash used to eliminate duplicates from @$coordinates
    my $noDups = {};

    foreach my $coord (@$coordinates){
	next if ($noDups->{$coord});
	$noDups->{$coord} = 1;

	push @sitelocs, {'pos'=>$coord,
			 'type'=>"site_loc",
			 'name'=>"loc$coord",
			 'orig_name'=>"$coord",
			 'revcomp'=>0,
			};
	# subtracting 1 because the siteloc really isn't a site location in Chado-style base-based 
	# coordinates; rather, it is an interval of length 1
	push @sitelocsrev, {'pos'=>$seq_length-$coord-1,
			    'type'=>"site_loc",
			    'name'=>"revloc$coord",
			    'orig_name'=>"$coord",
			    'revcomp'=>1,
			};
    }
    $noDups = undef;
    my $exonlist = undef;

    # shortcut #1: check in hash to see whether this sequence has any genes/exons (if hash provided)
    if (defined($seq_id_to_num_genes)) {
	my $num_genes = $seq_id_to_num_genes->{$seq_id};
	$exonlist = [] if (!defined($num_genes) || ($num_genes == 0));
    }
    $exonlist = $self->seq_id_to_exons($seq_id) if (!defined($exonlist));

    # shortcut #2: there can't be any transcript or CDS features if there are no exons
    my $transcriptlist = scalar(@$exonlist) ? $self->seq_id_to_transcripts($seq_id) : [];
    my $CDSlist = scalar(@$exonlist) ? $self->seq_id_to_CDS($seq_id) : []; # TODO - grab protein_id from here

    my @transcripts;
    my @transcriptsrev;
 
    my @CDSs;
    my @CDSsrev;

    my @exons;
    my @exonsrev;
    
    my $transcript_lookup;

    &_ensure_end5_lt_end3($exonlist);
    foreach my $exon (@$exonlist){
	if(($exon->{'end5'} < $exon->{'end3'}) && ($exon->{'strand'} != -1)){
	    my $exonelt = &_addEltToCustomArray(\@exons,$exon->{'end5'},"exon",$exon->{'end5'},$exon->{'end3'},"beg",$exon->{'exon_id'});
	    &_addEltToCustomArray(\@exons,$exon->{'end3'},"exon",$exon->{'end5'},$exon->{'end3'},"end",$exon->{'exon_id'});
	    $transcript_lookup->{$exon->{'transcript_id'}}->{'exons'} = [] if(!($transcript_lookup->{$exon->{'transcript_id'}}->{'exons'}));
	    push @{$transcript_lookup->{$exon->{'transcript_id'}}->{'exons'}}, $exonelt;
	}
	else{
	    my $exoneltrev = &_addEltToCustomArray(\@exonsrev,($seq_length-$exon->{'end3'}),"exon",($seq_length-$exon->{'end3'}),($seq_length-$exon->{'end5'}),"beg",$exon->{'exon_id'});
	    &_addEltToCustomArray(\@exonsrev,($seq_length-$exon->{'end5'}),"exon",($seq_length-$exon->{'end3'}),($seq_length-$exon->{'end5'}),"end",$exon->{'exon_id'});
	    
	    $transcript_lookup->{$exon->{'transcript_id'}}->{'exons'} = [] if(!($transcript_lookup->{$exon->{'transcript_id'}}->{'exons'}));
	    push @{$transcript_lookup->{$exon->{'transcript_id'}}->{'exons'}}, $exoneltrev;
	}
    }

    &_ensure_end5_lt_end3($CDSlist);
    foreach my $cds (@$CDSlist){
	if(($cds->{'end5'} < $cds->{'end3'}) && ($cds->{'strand'} != -1)){
	    my $cdselt = &_addEltToCustomArray(\@CDSs,$cds->{'end5'},"cds",$cds->{'end5'},$cds->{'end3'},"beg",$cds->{'cds_id'});
	    &_addEltToCustomArray(\@CDSs,$cds->{'end3'},"cds",$cds->{'end5'},$cds->{'end3'},"end",$cds->{'cds_id'});
	    $cdselt->{'protein'} = $cds->{'protein'};
	    $cdselt->{'protein_id'} = $cds->{'protein_id'};
	    $transcript_lookup->{$cds->{'transcript_id'}}->{'cds'} = $cdselt;
	}
	else{
	    my $cdselt = &_addEltToCustomArray(\@CDSsrev,($seq_length-$cds->{'end3'}),"cds",($seq_length-$cds->{'end3'}),($seq_length-$cds->{'end5'}),"beg",$cds->{'cds_id'});
	    &_addEltToCustomArray(\@CDSsrev,($seq_length-$cds->{'end5'}),"cds",($seq_length-$cds->{'end3'}),($seq_length-$cds->{'end5'}),"end",$cds->{'cds_id'});
	    $cdselt->{'protein'} = $cds->{'protein'};
	    $cdselt->{'protein_id'} = $cds->{'protein_id'};
	    $transcript_lookup->{$cds->{'transcript_id'}}->{'cds'} = $cdselt;
	}
    }

    &_ensure_end5_lt_end3($transcriptlist);
    foreach my $transcript (@$transcriptlist){
	if(($transcript->{'end5'} < $transcript->{'end3'}) && ($transcript->{'strand'} != -1)){
	    my $transcriptelt = &_addEltToCustomArray(\@transcripts,$transcript->{'end5'},"transcript",$transcript->{'end5'},$transcript->{'end3'},"beg",$transcript->{'transcript_id'});
	    &_addEltToCustomArray(\@transcripts,$transcript->{'end3'},"transcript",$transcript->{'end5'},$transcript->{'end3'},"end",$transcript->{'transcript_id'});
	    $transcriptelt->{'exons'} = $transcript_lookup->{$transcript->{'transcript_id'}}->{'exons'};
	    $transcriptelt->{'cds'} = $transcript_lookup->{$transcript->{'transcript_id'}}->{'cds'};
	}
	else{
	    my $transcriptelt = &_addEltToCustomArray(\@transcriptsrev,($seq_length-$transcript->{'end3'}),"transcript",($seq_length-$transcript->{'end3'}),($seq_length-$transcript->{'end5'}),"beg",$transcript->{'transcript_id'});
	    &_addEltToCustomArray(\@transcriptsrev,($seq_length-$transcript->{'end5'}),"transcript",($seq_length-$transcript->{'end3'}),($seq_length-$transcript->{'end5'}),"end",$transcript->{'transcript_id'});
	    $transcriptelt->{'exons'} = $transcript_lookup->{$transcript->{'transcript_id'}}->{'exons'};
	    $transcriptelt->{'cds'} = $transcript_lookup->{$transcript->{'transcript_id'}}->{'cds'};
	}
    }

    my $debug = 0;
    &_coordinates_to_coding_info(\@sitelocs,\@transcripts,\@CDSs,\@exons,0,$debug);
    &_coordinates_to_coding_info(\@sitelocsrev,\@transcriptsrev,\@CDSsrev,\@exonsrev,1,$debug);

    # collapse redundant sitelocs + reversed sitelocs back into a single set
    my $locreport = {};

    # note that the following code depends crucially on the duplicate elimination performed when @sitelocs
    # and @sitelocsrev were first constructed

    foreach my $loc (sort {$a->{'pos'} <=> $b->{'pos'}} (@sitelocs,@sitelocsrev)){
	my $locAlreadyDefined = exists($locreport->{$loc->{'orig_name'}});

	# CASE 1: either this siteloc is the first one we've seen at this position, or the existing siteloc
	# at this position has type = intergenic (i.e. allow a siteloc in @sitelocsrev to override its 
	# counterpart in @sitelocs iff the former has overlap_type = intergenic)
	if(!$locAlreadyDefined || ($locreport->{$loc->{'orig_name'}}->{'type'} eq "intergenic")){
	    if($loc->{'overlap_type'} eq "coding"){
		$locreport->{$loc->{'orig_name'}}->{'transcript'} = $loc->{'transcript'}->{'name'};
		$locreport->{$loc->{'orig_name'}}->{'cds'} = $loc->{'cds'}->{'name'};
		$locreport->{$loc->{'orig_name'}}->{'protein_id'} = $loc->{'cds'}->{'protein_id'};
		$locreport->{$loc->{'orig_name'}}->{'AAcoord'} = $loc->{'AAcoord'};
		$locreport->{$loc->{'orig_name'}}->{'AAresidue'} = $loc->{'AAresidue'};
	    }
	    elsif($loc->{'overlap_type'} eq "UTR" || $loc->{'overlap_type'} eq "intronic"){
		$locreport->{$loc->{'orig_name'}}->{'transcript'} = $loc->{'transcript'};
	    }
	
	    $locreport->{$loc->{'orig_name'}}->{'type'} = $loc->{'overlap_type'};

	    # $loc comes from @sitelocsrev
	    if($loc->{'revcomp'} == 1){
		# this -1 mirrors the one used when the siteloc was added to @sitelocsrev (see above)
		my $origCoord = ($seq_length - $loc->{'pos'}) - 1;
		$locreport->{$loc->{'orig_name'}}->{'nuc_coord'} = substr($$residues,$origCoord,1);
		$locreport->{$loc->{'orig_name'}}->{'pos'} = $origCoord;
	    }
	    # $loc comes from @sitelocs
	    else{
		$locreport->{$loc->{'orig_name'}}->{'nuc_coord'} = substr($$residues,$loc->{'pos'},1);
		$locreport->{$loc->{'orig_name'}}->{'pos'} = $loc->{'pos'};
	    }
	}
	# CASE 2: we have two sitelocs at this position, and the first of the two is not 'intergenic'
	elsif ($locAlreadyDefined) {
	    my $oldLocType = $locreport->{$loc->{'orig_name'}}->{'type'};
	    my $newLocType = $loc->{'overlap_type'};

	    # CASE 2a: one of the two sitelocs has type = 'unknown'; in this case the final
	    # merged siteloc should have type = 'unknown'
	    if (($oldLocType eq 'unknown') || ($newLocType eq 'unknown')) {
		$locreport->{$loc->{'orig_name'}}->{'type'} = 'unknown';
		$locreport->{$loc->{'orig_name'}}->{'transcript'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'cds'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'protein_id'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'AAcoord'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'AAresidue'} = undef;
	    }
	    # CASE 2b: neither of the two sitelocs has type = 'intergenic'; in this case the 
	    # final merged siteloc should have type 'multiple' (i.e., the site overlaps with
	    # > 1 transcript)
	    elsif (($oldLocType ne 'intergenic') && ($newLocType ne 'intergenic')) {
		$locreport->{$loc->{'orig_name'}}->{'type'} = 'multiple';
		$locreport->{$loc->{'orig_name'}}->{'transcript'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'cds'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'protein_id'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'AAcoord'} = undef;
		$locreport->{$loc->{'orig_name'}}->{'AAresidue'} = undef;
	    }
	}
    }
    return $locreport;
}

sub fs_id_to_edit_report {
    my($self, $fs_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_fs_id_to_edit_report($fs_id);
    
    my @fields = (#'row',
		  'feat_id',
		  'fs_id',
		  'report',
		  'person',
		  'date_loaded',
		  'olpaid',
		  'end5',
		  'end3',
		  'edit_comment',
		  'repair_num');

    return create_hash(\@fields, $ret);
}

sub fs_id_to_sequence {
    my($self, $fs_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_fs_id_to_sequence($fs_id);

    my @fields = ('subst_old',
		  'subst_new');
    
    return create_hash(\@fields, $ret);
}

sub fs_id_to_region_evaluation {
    my($self, $fs_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_fs_id_to_region_evaluation($fs_id);
    
    my @fields = ('lab_person',
		  'lab_date',
		  'num_repaired',
		  'lab_comment');

    return create_hash(\@fields, $ret);
}

sub frameshift_id_to_frameshift_location {
    my($self, $frameshift_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_frameshift_id_to_frameshift_location($frameshift_id, $db);

    my @fields = ('frameshift_id',
		  'frameshift_name',
		  'gene_id',
		  'gene_name',
		  'fmin',
		  'fmax',
		  'assembly_id',
		  'is_obsolete',
          'frameshift_strand');

    return create_hash(\@fields, $ret); 
}

sub validate_frameshift {
    my($self, $frameshift_id, $db) = @_;
    my @fs = $self->frameshift_id_to_frameshift_location($frameshift_id, $db);
    my $ret = $self->{_backend}->do_validate_frameshift($fs[0][0],$db);
    return $ret;
}

sub invalidate_frameshift {
    my($self, $frameshift_id, $db) = @_;
    my @fs = $self->frameshift_id_to_frameshift_location($frameshift_id, $db);
    my $ret = $self->{_backend}->do_invalidate_frameshift($fs[0][0],$db);
    return $ret;
}

sub ignore_frameshift {
    my($self, $frameshift_id, $db) = @_;
    my @fs = $self->frameshift_id_to_frameshift_location($frameshift_id, $db);
    my $ret = $self->{_backend}->do_ignore_frameshift($fs[0][0],$db);
    return $ret;
}

sub unignore_frameshift {
    my($self, $frameshift_id, $db) = @_;
    my @fs = $self->frameshift_id_to_frameshift_location($frameshift_id, $db);
    my $ret = $self->{_backend}->do_unignore_frameshift($fs[0][0],$db);
    return $ret;
}
#######################################
#^ END FS_ID (FRAMESHIFT) INPUT_TYPE ^#
##################################################################

###################################
#     ANALYSIS_ID INPUT_TYPE      #
###################################

sub analysis_id_to_feature_ids {
    my($self, $analysis_id, $feature_type) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
  
    my $ret = $self->{_backend}->get_analysis_id_to_feature_ids($analysis_id, $feature_type);

    my @fields = ('feature_id',);
    
    return create_hash(\@fields, $ret);
}

# Retrieve the features associated with a particular match_feature
sub match_feature_id_to_features {
    my($self, $feature_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @features;

    # Get the polypeptides in the match
    my $srcfeats = $self->feature_id_to_featureloc_feature_ids( $feature_id );
    foreach my $sf ( @$srcfeats ) {
	# Get the annotated transcripts associated with the polypeptides
	my $trs = $self->polypeptide_id_to_transcript_id( $sf->{feature_id} );
	die "More than 1 transcript associated with polypeptide" if ( @$trs > 1 );
	foreach my $tr (@$trs) {
	    # Get the assertion object
	    my $asserts = $self->feature_id_to_assertions( $tr->{feature_id} );
	    
	    # Add in the uniquename
	    $asserts->{uniquename} = $tr->{uniquename};

	    push( @features, $asserts );
      }
    }

    return @features;
}

# return feature_id and type
sub feature_id_to_featureloc_feature_ids {
    my($self, $feature_id) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_feature_id_to_featureloc_feature_ids($feature_id);

    my @fields = ('feature_id','uniquename', 'type');
    
    return create_hash(\@fields, $ret);

}

# return the transcript(s?) associated with a polypeptide
sub polypeptide_id_to_transcript_id {
    my($self, $feature_id) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_polypeptide_id_to_transcript_id($feature_id);

    my @fields = ('feature_id','uniquename',);
    
    return create_hash(\@fields, $ret);  
}

# return assertions object
sub feature_id_to_assertions {
    my($self, $feature_id) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $assert = { feature_id => $feature_id, };

    # EC Numbers as array of hashrefs
    $assert->{ec} = $self->feature_id_to_EC_numbers( $feature_id );
    
    # Pull all featureprops
    my $fps = $self->feature_id_to_featureprops( $feature_id );
    foreach my $fp ( @$fps ) {
	my ($name, $value) = ($fp->{name}, $fp->{value});
	# handle properties that can only have a single value
	if ( $name eq 'gene' || $name eq 'gene_product_name') {
	    if ( defined( $assert->{$name} ) && ( $assert->{$name} ne $value ) ) {
		die "Conflict in $name ($value ne ". $assert->{$name}.")";
	    }
	    $assert->{$name} = $value;
	}
    }

    return $assert;
}

# retrieve EC number assignments for a given feature
sub feature_id_to_EC_numbers {
    my($self, $feature_id) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_feature_id_to_EC_numbers( $feature_id );

    my @fields = ('accession', 'name');
    
    return create_hash(\@fields, $ret);
}

# retrieve featureprops for a feature_id (optionally of a provided type)
sub feature_id_to_featureprops {
    my($self, $feature_id, $name) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_feature_id_to_featureprops( $feature_id, $name );

    my @fields = ('featureprop_id', 'name', 'value', 'rank',);
    
    return create_hash(\@fields, $ret);

}

# this should probably live in a Harmogene module
# get the rules associated with a (match) feature
# they're stored as a featureprop
sub feature_id_to_rules {
    my($self, $feature_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $rules = $self->feature_id_to_featureprops($feature_id, 'virulence');

    die  " > 1 rules text strings" if (@$rules > 1);

    return $rules->[0];
}


sub set_feature_id_rules {
    my($self, $feature_id, $rules) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $old_rules = $self->feature_id_to_rules( $feature_id );

    if ( $old_rules ) { # update existing
	$self->{_backend}->do_update_featureprop_value( $old_rules->{featureprop_id}, $rules );
    } else { # add new 
	$self->{_backend}->do_insert_featureprop( $feature_id, 'virulence', $rules );
	
    }
}

# All of this rules stuff should probably live somewhere else
sub apply_rules_to_features {
    my($self, $features, $rule) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->parse_rules_text($rule);


}

# this doesn't even need to be a method function
# stealing code from apply_rules_to_assertions.pl
sub parse_rules_text {
    my ($self, $rules) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    foreach my $rule ( split("\n", $rules) ) {
	print "RULE: $rule\n";
    }

}


# pull taxon_id, organism_id, common_name
sub taxon_organism_info {
    my ($self) = @_;  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_taxon_organism_info(  );

    my @fields = qw{ taxon_id organism_id common_name };
    
    return create_hash(\@fields, $ret);
}

# pull info on features of given type associated with organism_id
sub organism_id_to_features {
    my($self, $organism_id, $type) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_organism_id_to_features( $organism_id, $type );

    my @fields = qw{ feature_id organism_id name uniquename type_id fmin fmax strand };
    
    return create_hash(\@fields, $ret);
}

# retrieve the feature record of a provided uniquename
sub gene_id_to_feature {
    my($self, $uniquename) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_gene_id_to_feature( $uniquename );

    my @fields = qw{ feature_id organism_id name uniquename type_id fmin fmax strand };
    
    return create_hash(\@fields, $ret);
}

# retrieve the feature annotations stored as cvterms
# optionally, from a specific cv, feature_id
sub retrieve_feature_cvterms {
    my($self, $cv, $feature_id) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_retrieve_feature_cvterms( $cv, $feature_id );

    my @fields = qw( cv_name feature_id feature_cvterm_id cvterm_id name accession );
    
    return create_hash(\@fields, $ret);
}

# Retrieve the feature ids of the match features in a tag
# TODO: make organism, analysis optional
sub match_feature_tag_to_match_features {
    my($self, $featureprop_value, $organism_id, $analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_match_feature_tag_to_match_features( $featureprop_value, $organism_id, $analysis_id );

    my @fields = qw( tag feature_id uniquename organism_id analysis_id );
    
    return create_hash(\@fields, $ret);
}

# Update or create a gene_product_name for the provided feature.uniquename
# If the name is 'DELETE' it will be deleted (untested)
# This wrapper did not exist, although do_update_gene_product_name did
# in the individual Mysql/Sybase specific code
sub update_gene_product_name {
    my($self, $uniquename, $value) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_gene_product_name( $uniquename, $value);
}

# Update or create a gene_symbol for the provided feature.uniquename
# If the name is 'DELETE' it will be deleted (untested)
sub update_gene_symbol {
    my($self, $uniquename, $value) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_gene_symbol( $uniquename, $value);
}

# For the provided feature.uniquename, wipe existing GO terms
# and add in new ones ($value could be comma delimited)
sub update_GO_terms {
    my($self, $uniquename, $value) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_GO_terms( $uniquename, $value);
}

# For the provided feature.uniquename, wipe existing EC terms
# and add in new ones ($value could be comma delimited)
sub update_EC_terms {
    my($self, $uniquename, $value) = @_;
  
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_EC_terms( $uniquename, $value);
}

#########################################
#^     END ANALYSIS_ID INPUT_TYPE      ^#
#########################################


############################
#     MISC INPUT_TYPE      #
############################

sub dbtest{
    my($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_dbtest();

    return $ret->[0][0];
}

sub custom_query_to_results {
    my ($self, $query, @args) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_custom_query_to_results($query, @args);
}


# correct a listref of interval locations for a potential bug in the database layer
sub _ensure_end5_lt_end3 {
    my($rows) = @_;
    foreach my $row (@$rows) {
	my $end5 = $row->{'end5'};
	my $end3 = $row->{'end3'};

	if ($end5 > $end3) {
	    $row->{'end5'} = $end3;
	    $row->{'end3'} = $end5;
	    $row->{'strand'} = -1;
	}
    }
}

sub _coordinates_to_coding_info{
    my($sitelocs,$transcripts,$cds,$exons,$isrev,$debug) = @_;
    my(@allfeats) = (sort {
	if($a->{'pos'} eq $b->{'pos'}){ #features have same start location
	    &_getOrder($a->{'type'},$a->{'pos_type'}) <=> &_getOrder($b->{'type'},$b->{'pos_type'})
	}
	else{
	    $a->{'pos'} <=> $b->{'pos'}
	}
    } (@$transcripts,@$cds,@$exons,@$sitelocs));

    my $withinTranscript=0;
    my $withinCDS=0;
    my $withinExon=0;

    # maintain a list of current transcript and cds features

    my @transcript_list = ();
    my @cds_list = ();

    foreach my $feat (@allfeats){
	if ($debug) {
	    print STDERR "pos=", $feat->{'pos_type'}, " ", $feat->{'pos'}, " type=", $feat->{'type'}, " name=", $feat->{'name'}, "\n";
	}

	if($feat->{'type'} eq "transcript"){
	    &_setVariable(\$withinTranscript,$feat);
	    if($feat->{'pos_type'} eq "beg") {
		push(@transcript_list, $feat);
	    } else {
		my @new_list = ();
		my $removed = 0;
		foreach my $t (@transcript_list) {
		    if ($t->{'name'} ne $feat->{'name'}) {
			push(@new_list, $t);
		    } else {
			++$removed;
		    }
		}
		print STDERR "Coati.pm: WARNING - $removed element(s) removed from current transcript list\n" if ($removed != 1);
		@transcript_list = @new_list;
	    }
	}
	elsif($feat->{'type'} eq "cds"){
	    &_setVariable(\$withinCDS,$feat);
	    if($feat->{'pos_type'} eq "beg") {
		push(@cds_list, $feat);
	    } else {
		my @new_list = ();
		my $removed = 0;
		foreach my $t (@cds_list) {
		    if ($t->{'name'} ne $feat->{'name'}) {
			push(@new_list, $t);
		    } else {
			++$removed;
		    }
		}
		print STDERR "Coati.pm: WARNING - $removed element(s) removed from current cds list\n" if ($removed != 1);
		@cds_list = @new_list;
	    }
	}
	elsif($feat->{'type'} eq "exon"){
	    &_setVariable(\$withinExon,$feat);
	}
	elsif($feat->{'type'} eq "site_loc"){
	    if($withinTranscript >=2) {
		$feat->{'overlap_type'} = "multiple";
	    } 
	    elsif($withinTranscript >=1 && $withinCDS >= 1 && $withinExon >= 1){
		$feat->{'overlap_type'} = "coding";
		# last element on the list was added last
		my $ctrans = $transcript_list[$#transcript_list];
		my $ccds = $cds_list[$#cds_list];

		$feat->{'transcript'} = $ctrans;
		$feat->{'cds'} = $ccds;
		$feat->{'AAcoord'} = &_mapNucCoord2AACoord($feat->{'pos'},$ctrans,$isrev);

		# Sanity check; this should never happen
		if (int($feat->{'AAcoord'}) < 0) {
		    print STDERR "Coati.pm: ERROR - extracting AAResidue at position ", $feat->{'AAcoord'}, " for cds $ccds\n";
		    print STDERR "currcds = " . join(' ', map { $_ . '=' . $ccds->{$_} } keys %$ccds) . "\n";
		    print STDERR "currtranscript = " . join(' ', map { $_ . '=' . $ctrans->{$_} } keys %$ctrans) . "\n";
		    print STDERR "feat_pos=", $feat->{'pos'}, " isrev=$isrev\n";
		}

		my $protSeq = $ccds->{'protein'};
		my $aares = substr($protSeq,int($feat->{'AAcoord'}),1);

		# Special case - if AAcoord is just after the end of the protein sequence and the
		# protein sequence does not end in a stop codon, then we assume that one should be
		# inserted and reported.
		if (!defined($aares) || ($aares eq '')) {
		    my $protLen = defined($protSeq) ? length($protSeq) : 0;
		    if (($protLen > 0) && (int($feat->{'AAcoord'}) == $protLen) && ($protSeq !~ /\*$/)) {
			$aares = '*';
		    }
		}

		# Some genes have missing or truncated proteins.  In prokaryotic genomes in particular
		# this may be due to the presence of frameshifts.  SNPs that overlap with such proteins
		# will still be given the type 'coding', but the character '?' will be used to denote
		# that the amino acid at that location is unknown.
		$aares = '?' if (!defined($aares));
		$feat->{'AAresidue'} = $aares
	    }
	    elsif($withinTranscript >= 1 && $withinExon == 0){
		$feat->{'overlap_type'} = "intronic";
	    }
	    elsif($withinTranscript >= 1 && $withinCDS == 0 && $withinExon >= 1){
		$feat->{'overlap_type'} = "UTR";
	    }
	    elsif($withinTranscript == 0){
		$feat->{'overlap_type'} = "intergenic";
	    }
	    else{
		print "Couldn't find type for site_loc $feat->{'name'} transcript: $withinTranscript cds: $withinCDS exon: $withinExon\n";
		$feat->{'overlap_type'} = "unknown";
	    }
	}
	if ($debug) {
	    print STDERR " withinTrans=$withinTranscript withinCDS=$withinCDS withinExon=$withinExon ctrans=";
	    print STDERR join(',', @transcript_list), " ccds=", join(',', @cds_list), "\n";
	}
    }
}

sub _mapNucCoord2AACoord{
    my($coord,$transcript,$isrev) = @_;
    my $exons = $transcript->{'exons'};
    my $cds = $transcript->{'cds'};
    my $codingpos=0;
    my $currstart =0;

    foreach my $exon (sort {$a->{'pos'} <=> $b->{'pos'}} @$exons){
	if($cds->{'beg'} >= $exon->{'beg'} && $cds->{'beg'} <= $exon->{'end'}){
	    $codingpos += ($cds->{'beg'} - $exon->{'beg'});
	    $currstart = $cds->{'beg'};
	}
	else{
	    $currstart = $exon->{'beg'};
	}
	
	if($coord >= $exon->{'beg'} && $coord <= $exon->{'end'}){
	    my $pos = ($codingpos + ($coord - $currstart));
	    # correct for off-by-one error for reverse-strand transcripts
#	    return $isrev ? ($pos-1)/3.0 : $pos/3.0;
	    return $pos/3.0;
	}
	else{
	    $codingpos += ($exon->{'end'} - $currstart);
	}
    }
    return -1;
}

sub _getOrder{
    my($type,$pos_type)= @_;
    #ordering of features at same position is as follows:
    # forward-strand: transcript_beg<exon_beg<cds_beg<cds_end<exon_end<transcript_end<site_loc
    if($pos_type eq "beg"){
	if($type eq "transcript"){
	    return 0;
	}
	elsif($type eq "exon"){
	    return 1;
	}
	elsif($type eq "cds"){
	    return 2;
	}
    }
    elsif($pos_type eq "end"){
	if($type eq "cds"){
	    return 3;
	}
	elsif($type eq "exon"){
	    return 4;
	}
	if($type eq "transcript"){
	    return 5;
	}
    }
    elsif($type eq "site_loc"){
	return 6;
    }
}

sub _setVariable{
    my($var,$feat) = @_;
    if($feat->{'pos_type'} eq "beg"){
	$$var++;
    }
    elsif($feat->{'pos_type'} eq "end"){
	$$var--;
    }
}

sub _addEltToCustomArray{
    my($array,$pos,$type,$beg,$end,$pos_type,$name) = @_;
    my $elt = {'pos'=>$pos,
	       'type'=>$type,
	       'beg'=>$beg,
	       'end'=>$end,
	       'pos_type'=>$pos_type,
	       'name'=>$name
	       };
    push @$array,$elt;
    return $elt;
}

sub att_type_to_membrane_proteins {
    my ($self, $att_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $att_type = '' if(!$att_type);

    my $ret = $self->{_backend}->get_att_type_to_membrane_proteins($att_type, $db);

    my @fields = ('gene_id',
		  'att_type',
		  'score_type',
		  'score',
		  'product_name');

    return create_hash(\@fields, $ret);
}

sub att_type_to_gene_attributes {
    my ($self, $att_type, $att_order, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_att_type_to_gene_attributes($att_type, $att_order, $db);

    my @fields = ('gene_id',
		  'att_type',
		  'score_type',
		  'score',
		  'gene_name');

    return create_hash(\@fields, $ret);
}

sub ev_type_to_HMM_evidence {
    my ($self, $ev_type, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_ev_type_to_HMM_evidence($ev_type, $db);
    
    my @fields = ('accession',
		  'orf_count',
		  'name');

    return create_hash(\@fields, $ret);
}

sub ev_type_to_COG_evidence {
    my ($self, $ev_type, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_ev_type_to_COG_evidence($ev_type, $db);
    
    my @fields = ('accession',
		  'orf_count');

    return create_hash(\@fields, $ret);
}

sub ev_type_to_gene_evidence {
    my ($self, $ev_type, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my $ret = $self->{_backend}->get_ev_type_to_gene_evidence($ev_type, $db);
    
    my @fields = ('accession',
		  'orf_count',
		  'name',
		  'ev_type',
		  'hmm_acc');

    return create_hash(\@fields, $ret);
}

sub set_textsize {
    my ($self, $size) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $size = 200000000 if(!$size);

    $self->{_backend}->do_set_textsize($size);
}

sub conditional {
    my ($self, $query) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_conditional($query);

    return $ret->[0][0];
}

sub master_go_id_lookup {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    return $self->{_backend}->get_master_go_id_lookup($db);
    
}

sub organism_id_to_taxon_id {
    my ($self, $organism_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_organism_id_to_taxon_id($organism_id, $db);
    return $ret->[0][0];
}

sub search_str_to_organisms {
    my ($self, $search_str, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    my $ret = $self->{_backend}->get_search_str_to_organisms($search_str, $db);

    my @fields = ('seq_id',
		  'common_name',
		  'organism_id',
		  'taxon_id',
		  'brc_name');

    return create_hash(\@fields, $ret);
}



sub score_type_to_score_id{
    my($self,$score_type,$input_type)=@_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->get_score_type_to_score_id($score_type,$input_type);

    return($ret->[0][0]);
    }

##########################
#^ END MISC INPUT_TYPES ^#
##################################################################


sub hmm_data_lookup {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_hmm_data_lookup();
}




#################################

1;

