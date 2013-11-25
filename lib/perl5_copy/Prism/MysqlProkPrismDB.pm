package Prism::MysqlProkPrismDB;

use strict;
use base qw(Prism::ProkPrismDB Coati::Coati::MysqlProkCoatiDB);

my $MODNAME = "MysqlProkPrismDB.pm";

sub test_MysqlProkPrismPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ProkPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_MysqlProkPrismDB();

}

#----------------------------------------------------------------------------------------------
# get_gene_annotation_ident_attribute_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_ident_attribute_data {

    my ($self, $asmbl_id, $db, $schemaType ) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all ORF ident data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, i.nt_comment, i.auto_comment, i.gene_sym, i.start_edit, i.complete, i.auto_annotate, i.ec_, i.pub_comment ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ident i ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = i.feat_name ".
    "AND f.feat_type = 'ORF' ";

    if ( $schemaType eq 'ntprok' ){
	$query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, i.nt_comment, i.auto_comment, i.gene_sym, NULL, NULL, NULL, i.ec_, i.pub_comment  ".
	"FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..nt_ident i ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'NTORF' ";
    }


    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}


1;
