package Sequoia::ItemsInfo;
  
use strict;
use warnings;

sub items_info {	
	my ( $dbh, @barcodes ) = @_;
  
	#TODO: error checking / input validation

	if ( scalar @barcodes > 0 )
	{
		my $sql_query = "SELECT ";
		$sql_query .= "sierra_view.item_view.barcode, ";
		$sql_query .= "sierra_view.bib_view.record_num as bib_record_num, ";
		$sql_query .= "sierra_view.bib_view.title ";
		$sql_query .= "FROM sierra_view.bib_view, sierra_view.item_view, sierra_view.bib_record_item_record_link ";
		$sql_query .= "WHERE sierra_view.bib_view.id = sierra_view.bib_record_item_record_link.bib_record_id ";
		$sql_query .= "AND sierra_view.item_view.id = sierra_view.bib_record_item_record_link.item_record_id ";	
		$sql_query .= "AND sierra_view.item_view.barcode IN ( "  . join( " , ", ('?') x @barcodes ) . " ) ";  # insert a number of ? placeholders
		$sql_query .= ";";	

		my $sth = $dbh->prepare($sql_query);
		$sth->execute( @barcodes );

		#process results
		my %items_found;
		while( my $row = $sth->fetchrow_hashref) {
			$items_found{  $row->{'barcode'}  }{'barcode'} = $row->{'barcode'};  #this is a bit silly, but whatever
			$items_found{  $row->{'barcode'}  }{'bib_record_num'} = $row->{'bib_record_num'};
			$items_found{  $row->{'barcode'}  }{'title'} = $row->{'title'};
		}

		#return json
		return json => \%items_found;
	}
}

1;
