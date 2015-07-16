package Sequoia::BibItems;

use strict;
use warnings;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

sub items_for_bib_number
{
	my ( $dbh, $bibnumber, $icode1 ) = @_;

	my @item_ids = ();
	my $title = "";
	my $num_items_found = scalar ( @item_ids );

	my $sql_query = "SELECT ";
	$sql_query .= "sierra_view.item_view.barcode, ";
	$sql_query .= "sierra_view.bib_view.title ";
	$sql_query .= "FROM sierra_view.bib_view, sierra_view.item_view, sierra_view.bib_record_item_record_link ";
	$sql_query .= "WHERE sierra_view.bib_view.id = sierra_view.bib_record_item_record_link.bib_record_id ";
	$sql_query .= "AND sierra_view.item_view.id = sierra_view.bib_record_item_record_link.item_record_id ";

	#validate/munge the bibnumber ( we want to get it with no 'b' and no check digit )
	#possibly this validation should be done earlier
	if ( $bibnumber =~ m{ \A (b[0-9]{7})([x0-9]) \z }xmsi )
	{
		#takes the check digit off
		$bibnumber = $1;
	}
	elsif( $bibnumber =~ m{ \A (b[0-9]{7}) \z }xmsi  )
	{
		#there wasn't a check digit
		$bibnumber = $1;
	}
	else
	{
		#TODO: this is kludgy
		$bibnumber = '0';
	}

	$bibnumber =~ s/^(b|B)//;  #remove the leading b or B
	my $b_record_num = $bibnumber;
	$sql_query .= "AND sierra_view.bib_view.record_num = ? "; #  . $b_record_num . " ";

	#if icode1 was included, include it in the sql
	#TODO: input validation on this to make sure it's a number
	my $using_icode1 = 0;
	if ( looks_like_number($icode1) ){
		$using_icode1 = 1;
		$sql_query .= "AND sierra_view.item_view.icode1 = ? "; #'" . $icode1 . "' ";
	}

	$sql_query .= ";";

	my $sth = $dbh->prepare($sql_query);

	#pass right number of placeholders depending on icode1
	( $using_icode1 eq 1 ) ? $sth->execute( $b_record_num, $icode1 ) : $sth->execute( $b_record_num );

	#process results
	while( my $row = $sth->fetchrow_hashref) {
		push @item_ids, $row->{'barcode'};
		$title = $row->{'title'};
	}

	$num_items_found = scalar ( @item_ids );

	return json => {
		$bibnumber => {
		barcodes => \@item_ids,
		title => $title,
		num_items_found => $num_items_found
		}
	};
}

1;
