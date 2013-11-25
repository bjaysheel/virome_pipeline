package Coati::Sorters;

use strict;
#no strict 'refs';
####################################
#   FUNCTIONS FOR SORTING ARRAYS   #
####################################

sub sort_array_by_value {
    my ($arrayref, $key) = @_;
    return sort { $a->{$key} <=> $b->{$key} } @$arrayref;
}

sub sort_array_by_value_lexical {
    my ($arrayref, $key) = @_;
    return sort { lc($a->{$key}) cmp lc($b->{$key}) } @$arrayref;
}

sub sort_array_by_gene_name_lexical {
    my ($arrayref, $key) = @_;
    my $sort_arrayref;
    my $final_arrayref;
    
    for(my $i=0; $i<@$arrayref; $i++) {
	if(@$arrayref[$i]->{$key} =~ /^putative/) {
	    @$arrayref[$i]->{$key} =~ s/^putative\s+//;
	    @$arrayref[$i]->{$key} =~ s/$/CHANGED/g;
	}
	@$sort_arrayref[$i] = @$arrayref[$i];
    }
 
    @$final_arrayref = sort { lc($a->{$key}) cmp lc($b->{$key}) } @$sort_arrayref; 
    
    for(my $i=0; $i<@$final_arrayref; $i++) {
	if(@$final_arrayref[$i]->{$key} =~ /CHANGED$/) {
	    @$final_arrayref[$i]->{$key} =~ s/CHANGED$//;
	    @$final_arrayref[$i]->{$key} =~ s/^/putative /;
	}
    }
    return @$final_arrayref;
}

sub sort_array_by_reverse {
    my ($arrayref, $key) = @_;
    return sort { $b->{$key} <=> $a->{$key} } @$arrayref;
}

sub sort_array_by_reverse_lexical {
    my ($arrayref, $key) = @_;
    return sort { lc($b->{$key}) cmp lc($a->{$key}) } @$arrayref;
}


####################################
#  FUNCTIONS FOR SORTING HASH KEYS #
####################################

sub sort_hashkeys_by_value {
    my ($hashref) = @_;
    return sort {$hashref->{$a} <=> $hashref->{$b}} keys %$hashref;
}

sub sort_hashkeys_by_value_reverse {
    my ($hashref) = @_;
    return sort {$hashref->{$b} <=> $hashref->{$a}} keys %$hashref;
}

sub sort_hashkeys_by_value_lexical {
    my ($hashref) = @_; 
    return sort { lc($hashref->{$a}) cmp lc($hashref->{$b}) } keys %$hashref; 
}

sub sort_multihashkeys_by_value {
    my ($hashref,$key1) = @_;
    return sort {$hashref->{$a}->{$key1} <=> $hashref->{$b}->{$key1}} keys %$hashref;
}

sub sort_multihashkeys_by_reverse {
    my ($hashref,$key1) = @_;
    return sort {$hashref->{$b}->{$key1} <=> $hashref->{$a}->{$key1}} keys %$hashref;
}

sub sort_multihashkeys_by_value_lexical {
    my ($hashref,$key1) = @_;

    return sort { lc($hashref->{$a}->{$key1}) cmp lc($hashref->{$b}->{$key1})} keys %$hashref;
}

sub sort_multihashkeys_by_reverse_lexical {
    my ($hashref,$key1) = @_;

    return sort { lc($hashref->{$b}->{$key1}) cmp lc($hashref->{$a}->{$key1})} keys %$hashref;
}



#################################


##################################################################
#  FUNCTIONS FOR SORTING BY MULTIPLE HASH KEYS  (ARRAY OF HASHES)#
##################################################################
sub sort_multikeys_by_lexical {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$a->{$key1} cmp $b->{$key1} ||  $a->{$key2} cmp $b->{$key2}} @$arrayref;
}

sub sort_multikeys_by_numbers {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$a->{$key1} <=> $b->{$key1} ||  $a->{$key2} <=> $b->{$key2}} @$arrayref;
}

sub sort_multikeys_by_lexical_numbers {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$a->{$key1} cmp $b->{$key1} ||  $a->{$key2} <=> $b->{$key2}} @$arrayref;
}

sub sort_multikeys_by_numbers_lexical {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$a->{$key1} <=> $b->{$key1} ||  $a->{$key2} cmp $b->{$key2}} @$arrayref;
}

sub sort_multikeys_by_rev_lexical {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$b->{$key1} cmp $a->{$key1} ||  $b->{$key2} cmp $a->{$key2}} @$arrayref;
}

sub sort_multikeys_by_rev_numbers {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$b->{$key1} <=> $a->{$key1} ||  $b->{$key2} <=> $a->{$key2}} @$arrayref;
}

sub sort_multikeys_by_rev_lexical_numbers {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$b->{$key1} cmp $a->{$key1} ||  $a->{$key2} <=> $b->{$key2}} @$arrayref;
}

sub sort_multikeys_by_rev_numbers_lexical {
    my ($arrayref, $key1, $key2) = @_;
    return sort {$b->{$key1} <=> $a->{$key1} ||  $a->{$key2} cmp $b->{$key2}} @$arrayref;
}



1;
