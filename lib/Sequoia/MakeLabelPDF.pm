package Sequoia::MakeLabelPDF;

use strict;
use warnings;

use DBI;
use PDF::API2;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
    get_info_for_requested_items
    produce_and_distribute_labels
);

#TODO: get rid of this
my $granularity = 30; #in minutes; smaller than 60, normal value is 30.

#ITYP:
my %is_cassette_type  = map { $_ => 1 } qw( 62 60 67 65 61 66 );
my %is_reference_type = map { $_ => 1 } qw( 10 11 12 16 18 26 27 33 34 35 62 67 73 79 83 94 103 135 139 149 152 154 155 161 162 );

#ICT1:
my %is_disc_category  = map { $_ => 1 } qw( CD-BOOK CD-MUSIC CD-ROM VIDEO-DVD VIDEO-VHS PLAYAWAY ); #ICT1; VHS added on 2009/07/16 at request of Amanda Pittman
my %spine_gets_copy   = map { $_ => 1 } qw( CD-BOOK CD-MUSIC CASS-BOOK CASS-MUSIC PLAYAWAY ); #ICT1
#TODO: sierra ict1=bcode2
#%is_disc_category = map { $_ => 1 } qw( i j m g h p );
#%spine_gets_copy  = map { $_ => 1 } qw( i j 5 7 p );

#substr ( location_code, 0 , 2 ):
my %is_main_prefix 		= map { $_ => 1 } qw( 1c 1l 1h 1p 1f 2m 2n 3n 2r 2s 2g 2e 3d 3r 3a 3h 3l 4d 2t 2k 2x 3g 3e 3c 4c 4v 5a 5c 5o 5v 5d 5f 5s 5h 5i 5p 5m 5y 5n 5t );
my %is_branch_prefix 	= map { $_ => 1 } qw( an av ba bh ch cl co cr cv dp dt ep fo ge gh gr ha hp lv ma mm md mn mo mt mw nw nr ns oa pl pr re sh sb sm wh wt ww wy os ts);

#translate Sierra bcode2 into a Symphony ict1
my %ict1_for_bcode2 = (
	'a' => 'BOOK',
	'b' => 'GOVDOC',
	'g' => 'VIDEO-DVD',
	'i' => 'CD-BOOK',
	'5' => 'CASS-BOOK',
	'm' => 'CD-ROM',
	'1' => 'WEB-RSRCE',  #downloadable audiobook?
	'2' => 'WEB-RSRCE',  #downloadable book?
	'3' => 'WEB-RSRCE',  #downloadable music?
	'4' => 'WEB-RSRCE',  #downloadable video?
	'x' => 'WEB-RSRCE',  #emagazine?
	'y' => 'WEB-RSRCE',  #enewspaper?
	'z' => 'WEB-RSRCE',  #eresource?
	'l' => 'LARGEPRINT',
	's' => 'MAGAZINE',
	'6' => 'MICROFORM',
	'j' => 'CD-MUSIC',
	'7' => 'CASS-MUSIC',
	'c' => 'SCORE',
	'n' => 'NEWSPAPER',
	'q' => 'PLAYAWAY',
	'h' => 'VIDEO-VHS',
	'v' => 'WEB-RSRCE',  #web document?
	'w' => 'WEB-RSRCE',  #website?
	'-' => 'UNKNOWN'
	);

#translate a Sierra two-letter prefix into a three-letter agency code
my %agency_for_two_letter_prefix = (
		'1c' => 'CLC',
		'1l' => 'CLC',
		'1h' => 'HOM',
		'1p' => 'POP',
		'1f' => 'POP',
		'2m' => 'MAG',
		'2n' => 'MAG',
		'3n' => 'MAG',
		'2r' => 'IRF',
		'2s' => 'IRF',
		'2g' => 'IRF',
		'2e' => 'IRF',
		'3r' => 'IRF',
		'3a' => 'IRF',
		'3h' => 'IRF',
		'3l' => 'IRF',
		'4d' => 'IRF',
		'2t' => 'TEE',
		'2k' => 'TEE',
		'2x' => 'TCR',
		'3d' => 'GEN',
		'3g' => 'GEN',
		'3e' => 'GEN',
		'3c' => 'GEN',
		'an' => 'AND',
		'av' => 'AVO',
		'ba' => 'BLU',
		'bh' => 'BON',
		'ch' => 'CHE',
		'cl' => 'CLI',
		'co' => 'COL',
		'cr' => 'COR',
		'cv' => 'COV',
		'dp' => 'DEE',
		'dt' => 'DEL',
		'ep' => 'ELM',
		'fo' => 'FOR',
		'ge' => 'GRE',
		'gh' => 'GRN',
		'gr' => 'GRO',
		'ha' => 'HAR',
		'hp' => 'HYD',
		'lv' => 'LOV',
		'ma' => 'MAD',
		'mm' => 'MAR',
		'md' => 'MDI',
		'mn' => 'MIA',
		'mo' => 'MON',
		'mt' => 'MTH',
		'mw' => 'MTW',
		'nw' => 'NOR',
		'nr' => 'NRC',
		'ns' => 'NRS',
		'oa' => 'OAK',
		'pl' => 'PLS',
		'pr' => 'PRI',
		're' => 'REA',
		'sh' => 'SHA',
		'sb' => 'STB',
		'sm' => 'SYM',
		'wh' => 'WAL',
		'wt' => 'WES',
		'ww' => 'WST',
		'wy' => 'WYO',
		'os' => 'OUT',
		'4c' => 'CIR',
		'4v' => 'VIC',
		'5a' => 'ACQ',
		'5c' => 'CAT',
		'5o' => 'CLD',
		'5v' => 'CON',
		'5d' => 'DIR',
		'5f' => 'FAC',
		'5s' => 'FIN',
		'5h' => 'HUM',
		'5i' => 'LIB',
		'5p' => 'PRO',
		'5m' => 'PUB',
		'5y' => 'SEC',
		'5n' => 'SIS',
		'5t' => 'TEC',
        'ts' => "BR"
		);

my %ityp_is_floating  = map {$_=>1} qw( 1 3 5 21 23 158 160 );  #SIERRA: ityp code numbers.
my %ityp_can_float    = map {$_=>1} qw( BOOK 0 2 4 20 22 60 61 70 71 72 77 78 90 91 92 101 157 159 );  #SIERRA: itype code numbers.
my %libr_is_branch    = map {$_=>1} qw( an av ba bh ch cl co cr cv dp dt ep fo ge gh gr ha hp lv ma mm md mn mo mt mw nw nr ns oa pl pr re sh sb sm wh wt ww wy ts);  #take the branch prefix from location_code

sub locn_floats{
	my $locn = shift;
	my $location_code_4		= ( length $locn > 3 ) ? substr( $locn, 3, 1 ) : "";
	my $location_code_5		= ( length $locn > 4 ) ? substr( $locn, 4, 1 ) : "";
	my $shelf				= $location_code_4 . $location_code_5;

	#Sierra item location "suffixes"
	my %is_floating_shelf	= map { $_ => 1 } qw( oo aa ab af al an ao ar au bd bg bi c cb cc ce cf cg ch ci ch ck cl cm cn co cp cq cr cs cv cw cx cy cz d da dc df dm dr ds dt du eb ec er es f fc ff fh fl fm fp fr fs fw gn ho in kl l lf ln mc nf nr od  pb pl ps pu sb se sf sl ss st tv v vf vm );

	return 1 if $is_floating_shelf{$shelf};

	return 0;
}

#says_floating is used to decide whether to put the word "Floating" on item labels
sub says_floating {
    my %param = @_;
    my $ityp = $param{'ityp'} || '';  #these are sierra ityp numbers
    my $ict1 = $param{'ict1'} || '';  #these get translated to their old symphony names
    my $libr = $param{'libr'} || '';  #these are sierra agency numbers
    my $locn = $param{'locn'} || '';  #these are sierra shelf locations

	my $location_code_1_2 	= substr( $locn, 0, 2 );
	$libr = $location_code_1_2;

    # RV DEBUG
    # print STDERR "params: ityp: $ityp\t ict1: $ict1\t libr: $libr\t locn: $locn\n";
    # RV 2019-10-31 agency TS is floating 
    return 1 if $libr eq 'ts';

    return 0 if $ict1 eq 'VIDEO-VHS';

	#main dvd's float
    #SIERRA: MAIN = 1; "DVD/Videocassette" = "101"
    return 1 if $libr eq '1' && $ityp eq '101';

    #pop library
	if ($location_code_1_2 eq '1p' )
	{
		#new dvd's do not float
		return 0 if $ityp eq '100';
		#old dvd's do float
		return 1 if $ityp eq '101';
		#everything else in pop does not float
		return 0;
	}

    if ($libr_is_branch{$libr}) {
		#certain itypes float at branches
        return 1 if ($ityp_is_floating{$ityp});
        #certain itypes can float if they are certain shelf locations
        return 1 if $ityp_can_float{$ityp} && locn_floats($locn);
    }

	#eveything else doesn't float
    return 0;
}

sub get_info_for_requested_items {
	#---------------------------------------------------
	#
	# Get bib and item data from SQL for requested items
	#
	#---------------------------------------------------

    use List::Util qw( min );

    my ( $dbh, $label_request_ref, $item_info_ref ) = @_;

	#puts the itemids into an array.
	my @itemids = ();
    for my $date (keys %{$label_request_ref}) {
        for my $uacs (keys %{$label_request_ref->{$date}}) {
            for my $itemid (keys %{$label_request_ref->{$date}{$uacs}}) {
                push( @itemids, $itemid );
            }
        }
    }

	my $sql_query = "SELECT ";

	$sql_query .= "item_view.record_num, ";
	$sql_query .= "item_view.id, ";
	$sql_query .= "item_view.barcode, ";
	$sql_query .= "item_view.copy_num, ";
	$sql_query .= "item_view.icode1, ";
	$sql_query .= "item_view.location_code, ";
	$sql_query .= "item_view.itype_code_num, ";
	$sql_query .= "item_view.agency_code_num, ";

	$sql_query .= "sierra_view.bib_record_item_record_link.id, ";
	$sql_query .= "sierra_view.bib_view.title, ";
	$sql_query .= "sierra_view.bib_view.bcode2, ";

	$sql_query .= "sierra_view.record_metadata.record_last_updated_gmt, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.item_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'i' AND ";
	$sql_query .= "		 sierra_view.varfield_view.varfield_type_code = 'c' ";
	$sql_query .= "LIMIT 1 ) as item_callnum, ";		#callnum from the item record ( rather than from the bib )

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.varfield_type_code = 'c' ";
	$sql_query .= "LIMIT 1 ) as callnum, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.varfield_type_code = 'a' ";
	$sql_query .= "LIMIT 1 ) as author, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '086' ";
	$sql_query .= "LIMIT 1 ) as marc086, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '092' ";
	$sql_query .= "LIMIT 1 ) as marc092, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '100' ";
	$sql_query .= "LIMIT 1 ) as marc100, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '245' ";
	$sql_query .= "LIMIT 1 ) as marc245, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '300' ";
	$sql_query .= "LIMIT 1 ) as marc300, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_num = sierra_view.bib_view.record_num AND ";
	$sql_query .= "		 sierra_view.varfield_view.record_type_code = 'b' AND ";
	$sql_query .= "		 sierra_view.varfield_view.marc_tag = '955' ";
	$sql_query .= "LIMIT 1 ) as marc955, ";

	$sql_query .= "( SELECT sierra_view.varfield_view.field_content ";
	$sql_query .= "FROM sierra_view.varfield_view, sierra_view.volume_view, sierra_view.volume_record_item_record_link ";
	$sql_query .= "WHERE sierra_view.varfield_view.record_id = sierra_view.volume_view.id ";
	$sql_query .= "AND sierra_view.volume_view.id = sierra_view.volume_record_item_record_link.volume_record_id ";
	$sql_query .= "AND sierra_view.volume_record_item_record_link.item_record_id = sierra_view.item_view.id ";
	$sql_query .= "AND sierra_view.varfield_view.record_type_code = 'j' ";
	$sql_query .= "AND sierra_view.varfield_view.varfield_type_code = 'v' ";
	$sql_query .= "ORDER BY field_content DESC ";
	$sql_query .= "LIMIT 1 ) as volume_statement ";

	$sql_query .= "FROM sierra_view.item_view ";

	#join the bib
	$sql_query .= "JOIN sierra_view.bib_record_item_record_link ";
	$sql_query .= "ON sierra_view.item_view.id = sierra_view.bib_record_item_record_link.item_record_id ";
	$sql_query .= "JOIN sierra_view.bib_view ";
	$sql_query .= "ON sierra_view.bib_record_item_record_link.bib_record_id = sierra_view.bib_view.id ";

	#join the item record metadata
	$sql_query .= "JOIN sierra_view.record_metadata ";
	$sql_query .= "  ON sierra_view.record_metadata.id = sierra_view.item_view.id ";
	$sql_query .= " AND sierra_view.record_metadata.record_type_code = 'i' ";

	$sql_query .= "WHERE sierra_view.item_view.barcode IN ( " . join( " , ", ('?')x@itemids ) . " ) ";

	$sql_query .= ";";

	#start timing the SQL query
	my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	my $hhmmss = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	#print "query start at ".$hhmmss."...\n";

	my $sth = $dbh->prepare($sql_query);

	$sth->execute( @itemids );

	#end timing the SQL query
	( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime(time);
	$hhmmss = sprintf "%.2d:%.2d:%.2d", $hour, $min, $sec;
	#print "query finish at ".$hhmmss."...\n";

	my $items_info_found = 0;

	while( my $item_info = $sth->fetchrow_hashref() )
	{
		$items_info_found +=1;

		#libr - used to decide floating by the says_floating function
		my $libr = $item_info->{'agency_code_num'};

		#ict1 <- bib_view.bcode2 aka format aka mattype
		my $ict1 = ( defined $ict1_for_bcode2{ $item_info->{'bcode2'} } ) ? $ict1_for_bcode2{ $item_info->{'bcode2'} } : "";
		next if $ict1 eq 'WEB-RSRCE';

		#ict2?
		# must be: ADULT,TEEN,JUVENILE
		# location_code contains a,t,j in the 3rd char if the first two chars are a two-letter prefix
		my $agency = $item_info->{'location_code'};
		my $ict2 = "ADULT";
		my $location_code_1_2 	= substr( $item_info->{'location_code'}, 0, 2 );
		my $location_code_3 	= ( length $item_info->{'location_code'} > 2 ) ? substr( $item_info->{'location_code'}, 2, 1 ) : "";
		my $location_code_4		= ( length $item_info->{'location_code'} > 3 ) ? substr( $item_info->{'location_code'}, 3, 1 ) : "";
		my $location_code_5		= ( length $item_info->{'location_code'} > 4 ) ? substr( $item_info->{'location_code'}, 4, 1 ) : "";
		if ( $is_main_prefix{$location_code_1_2} || $is_branch_prefix{$location_code_1_2} )
		{
			#get ict2 from 3rd char
			if ( $location_code_3 eq 'a' )
			{
				$ict2 = 'ADULT';
			}
			elsif ( $location_code_3 eq 't' )
			{
				$ict2 = 'TEEN';
			}
			elsif ( $location_code_3 eq 'j' )
			{
				$ict2 = 'JUVENILE';
			}
			else
			{
				#something's not right
				$ict2 = 'ADULT';
			}

			#get agency from first two chars
			if ( $is_branch_prefix{$location_code_1_2} )
			{
				#branches are two-letter codes
                if ($location_code_1_2 eq 'ts')
                {
                    $agency = 'BR'
                }
                else 
                {
                    $agency = uc ( $location_code_1_2 );
                }
				
			}
			else
			{
				#look up what agency in the lookup table
				$agency = $agency_for_two_letter_prefix{$location_code_1_2};

				if (  $item_info->{'location_code'} eq '5fac' )
				{
					$agency = 'FAC';
				}
				if (  $item_info->{'location_code'} eq '5fis' )
				{
					$agency = 'FIN';
				}
				if (  $item_info->{'location_code'} eq '5cat' )
				{
					$agency = 'CAT';
				}
				if (  $item_info->{'location_code'} eq '5cld' )
				{
					$agency = 'CLD';
				}
			}
		}

        #RV DEBUG
        #print STDERR "agency: $agency\n";

		#itype code num -> ityp  ??
		my $ityp = $item_info->{'itype_code_num'};
		if ( $ityp eq '0' )
		{
			#this catches the wierd case where somehow "floating" comes back false due to ityp=0
			$ityp = "BOOK";
		}

		#title
		#my $title = $item_info->{'title'};
		my $title = ( defined $item_info->{'marc245'} ) ? $item_info->{'marc245'} : "";
		#remove linkage subfield
		if ( substr( $title, 0, 2 ) eq '|6' )
		{
			my $begin = index ( $title, '|', 2 );  #find the next subfield after the first one, which was the |6
			$title = substr( $title, $begin, ( length($title) - $begin ) );  #cut off the whole first subfield and take the rest
		}
		#misc other subfield id's
		$title =~ s/\|a//i;
		$title =~ s/\|b/ /i;
		$title =~ s/\|c/ /i;
		$title =~ s/\|h/ /i;
		$title =~ s/\|n/ /i;
		$title =~ s/\|p/ /i;
        $title =~ s{ [ ]+ \[ [^\]]+ \] [ ]* }{ }xms; #remove subfield h, which should be the first thing in brackets

		#browse
		my $browse = $item_info->{'title'};
        $browse =~ s/ \A 0+ ([1-9] [0-9]*) /$1/xms;  #initial zeros at start
        $browse =~ s/ ([^1-9]) (?<![.0]) 0+ ([1-9] [0-9]*) /$1$2/xmsg; # initial zeros within

		#author
		my $author = defined $item_info->{'author'} ? $item_info->{'author'} : "";
		#first remove linkage subfield
		if ( substr( $author, 0, 2 ) eq '|6' )
		{
			my $begin = index ( $author, '|', 2 );  #find the next subfield after the first one, which was the |6
			$author = substr( $author, $begin, ( length($author) - $begin ) );  #cut off the whole first subfield and take the rest
		}
        $author =~ s/\|a//i;
        $author = substr($author, 0, index($author, ',')) if index($author, ',') > -1;
		$author =~ s/\.$//i;

		#call number
		my $callnum = ( defined $item_info->{'callnum'} ) ? $item_info->{'callnum'} : '';
		$callnum =~ s/,//i;

		#classification
		my $callclass = "";
		if ( $item_info->{'bcode2'} eq 'b' )  #TODO: remove the contidional involving the 086
		{
			#the only time classification matters to the labels program is for SUDOC
			$callclass = 'SUDOC';
			$callnum = $item_info->{'marc086'};
		}

		#take callnum from item instead of bib.  overrides preceeding lines of code.
		#$callnum = ( defined $item_info->{'item_callnum'} ) ? $item_info->{'item_callnum'} : $callnum;

		if ( defined $item_info->{'volume_statement'} )
		{
			#append volume statement to the call number
			if ( $callclass eq 'SUDOC' )
			{
				#$callnum .= "_" . $item_info->{'volume_statement'};
				$callnum .= "" . $item_info->{'volume_statement'};
			}
			else
			{
				$callnum .= " " . $item_info->{'volume_statement'};
			}
		}

		$callnum =~ s/\|a//i;
		$callnum =~ s/\|b/ /i;
		if 	( 	( $ict2 eq 'JUVENILE' ) and
				( $callnum !~ /Easy/i or $callnum =~ /^PL-Spoken/i ) and
				( $ityp ne '100' and $ityp ne '101' )
			)
		{
			$callnum = "j$callnum";
		}

        $callnum = "R$callnum" if $is_reference_type{$ityp};

        $callnum =~ s/\b(v|no|pt)[.] +(\d+)/$1.$2/i;

		#start counting item pieces
		#--------------------------
        my $book_pieces = 0;
        my $disc_pieces = 0;

        my $marc300 = "";
        if ( defined $item_info->{'marc300'} )
        {
			$marc300 = $item_info->{'marc300'};
		}
        $marc300 =~ s/\|a//i;
        $marc300 =~ s/\|b/ /i;
        $marc300 =~ s/\|c/ /i;
        $marc300 =~ s/\|e/ /i;
        $marc300 =~ s{\([^)]*\)}{}g;
        $marc300 =~ s{\s+}{ }g; #collapse spaces
        $marc300 =~ s{^\s|\s^}{}g; #remove leading & trailing spaces
        my @subfields = split / [ ]* [+] [ ]* /xms, $marc300;
        my $first = shift @subfields;
        $first = "" unless (defined $first);

        for my $subsection (split / [ ]* [+] [ ]* /xms, $first) {
            if ($subsection =~ / ^ (\d+) \D+ (?: disc | dvd | cd | video ) /xmsi) {
                $disc_pieces += $1;
            }
            elsif ($subsection =~ / ^ (\d+) \s* (?: v[.] | \D+ cassette ) /xmsi) {
                $book_pieces += $1;
            }
        }

        if ($is_disc_category{$ict1}) {
            $disc_pieces = 1 if $disc_pieces == 0;
        }
        else {
            $book_pieces = 1 if $book_pieces == 0;
            use integer;
            $book_pieces = ( 1 + (($book_pieces - 1) / 4) ) if $is_cassette_type{$ityp};
        }

        for my $subfield ( @subfields ) {
            if ($subfield =~ / ^ (\d+) \D+ (?: disc | dvd | cd | video ) /xmsi) {
                $disc_pieces += $1;
            }
            elsif ($subfield =~ / ^ (\d+) \D+ (?: book | score | libretto | part | lea | card | guide | map | pbk | manual | dictionar | pattern ) /xmsi) {
                $book_pieces += $1;
            }
        }

        my $marc955_pieces = 1;
        if ( defined $item_info->{'marc955'} )
	{
            $item_info->{'marc955'} =~ s/\|a//i;
            if ($item_info->{'marc955'} =~ /([0-9]+)/ )
            {
                $marc955_pieces = $1;
            }
        }
        #end counting item pieces
        #------------------------

        #barcode is the key in the hash, so it must be defined
        my $barcode = ( defined $item_info->{'barcode'} ) ? uc $item_info->{'barcode'} : "";

		#places everything we want to know about this item into this item_info_ref hash
		#------------------------------------------------------------------------------
		$item_info_ref->{$barcode}{'barcode'}     = $barcode;
		$item_info_ref->{$barcode}{'record_num'}  = ( defined $item_info->{'record_num'} ) ? $item_info->{'record_num'} : "";
		$item_info_ref->{$barcode}{'title'}       = $title;
		$item_info_ref->{$barcode}{'browse'}      = $browse;
		$item_info_ref->{$barcode}{'author'}      = $author;
		$item_info_ref->{$barcode}{'callnum'}     = $callnum;
		$item_info_ref->{$barcode}{'callclass'}   = $callclass;
		$item_info_ref->{$barcode}{'copy'}        = ( defined $item_info->{'copy_num'} ) ? "c.".$item_info->{'copy_num'} : "";
		$item_info_ref->{$barcode}{'libr'}        = $libr;
		$item_info_ref->{$barcode}{'locn'}        = ( defined $item_info->{'location_code'} ) ? $item_info->{'location_code'} : "";
		$item_info_ref->{$barcode}{'agency'}      = $agency;
		$item_info_ref->{$barcode}{'ityp'}        = $ityp;
		$item_info_ref->{$barcode}{'ict1'}        = $ict1;
		$item_info_ref->{$barcode}{'ict2'}        = $ict2;
		$item_info_ref->{$barcode}{'book_pieces'} = min ($book_pieces, $marc955_pieces);
		$item_info_ref->{$barcode}{'disc_pieces'} = min ($disc_pieces, $marc955_pieces);
		$item_info_ref->{$barcode}{'updated_gmt'} = ( defined $item_info->{'record_last_updated_gmt'} ) ? $item_info->{'record_last_updated_gmt'} : "";
		$item_info_ref->{$barcode}{'icode1'} = ( defined $item_info->{'icode1'} ) ? $item_info->{'icode1'} : "";
    }

    return;
}

sub produce_and_distribute_labels {
	#------------------------------------
	#
	# For each request, create a label PDF
	#
	#------------------------------------
	#
	# This works by building the %book_labels_for and %disc_labels_for
	#
	#---------------------------------------------------------

    use integer; #for the division when calculating the period

    my ($label_request_ref, $item_info_ref, $arg_ref) = @_;

    $arg_ref->{'organize'} = 'normal' unless exists $arg_ref->{'organize'} && defined $arg_ref->{'organize'};
    $arg_ref->{'outputdir'} = '/test' unless exists $arg_ref->{'outputdir'} && defined $arg_ref->{'outputdir'};
    my %book_labels_for;
    my %disc_labels_for;

    my @done_labels;

	#TODO: rewrite this whole set of nested loops.  requires changed the shape of label_request_ref.

    for my $date (keys %{$label_request_ref}) {

        for my $uacs (keys %{$label_request_ref->{$date}}) {

            ITEM_FOR_USER:
            for my $itemid (keys %{$label_request_ref->{$date}{$uacs}}) {

                next ITEM_FOR_USER unless exists $item_info_ref->{$itemid};

                push( @done_labels, $item_info_ref->{$itemid}{'record_num'} );
                my $period;
                if ($arg_ref->{'organize'} eq 'replacements') {
                    $period = $date;
                }
                else {
                    my $minutes = 60 * substr($label_request_ref->{$date}{$uacs}{$itemid}, 0 , 2) + substr($label_request_ref->{$date}{$uacs}{$itemid}, 3 , 2);
                    $minutes -= $minutes % $granularity;
                    $period = sprintf "%02d:%02d", $minutes / 60, $minutes % 60;
                }

                if ($is_disc_category{ $item_info_ref->{$itemid}{'ict1'} }) {
                    push @{$disc_labels_for{$uacs}{$date}{$period}}, {'itemid'=>$itemid, 'time'=>$item_info_ref->{$itemid}{'updated_gmt'}, 'pieces'=>$item_info_ref->{$itemid}{'disc_pieces'} };
                    if ($item_info_ref->{$itemid}{'book_pieces'} > 0) {
                        push @{$book_labels_for{$uacs}{$date}{$period}}, {'itemid'=>$itemid, 'time'=>$item_info_ref->{$itemid}{'updated_gmt'}, 'pieces'=>$item_info_ref->{$itemid}{'book_pieces'} };
                    }
                }
                else {
                    push @{$book_labels_for{$uacs}{$date}{$period}}, {'itemid'=>$itemid, 'time'=>$item_info_ref->{$itemid}{'updated_gmt'}, 'pieces'=>$item_info_ref->{$itemid}{'book_pieces'} };
                    if ($item_info_ref->{$itemid}{'disc_pieces'} > 0) {
                        push @{$disc_labels_for{$uacs}{$date}{$period}}, {'itemid'=>$itemid, 'time'=>$item_info_ref->{$itemid}{'updated_gmt'}, 'pieces'=>$item_info_ref->{$itemid}{'disc_pieces'} };
                    }
                }
            }
        }
    }

	#TODO: better names for these files
	my %results;
	$results{'bookfilename'} = "Book.pdf";
	$results{'discfilename'} = "Disc.pdf";

	#makes a call to create_label_PDFs() for books and one for discs
    {
        $results{'bookfilename'} = create_label_PDFs( $item_info_ref, 'Book', \%book_labels_for, $arg_ref->{'workdir'} );
    }

    {
        $results{'discfilename'} = create_label_PDFs( $item_info_ref, 'Disc', \%disc_labels_for, $arg_ref->{'workdir'} );
    }

	my $num_done_labels = @done_labels;  #TODO: is this right?
	$results{'donelabels'} = $num_done_labels;

    return %results;
}

sub create_label_PDFs {
	#------------------------------------
	#
	# For a given item, create the PDF
	#
	#------------------------------------

    use English;
    use List::Util qw( first );
    use Net::FTP;
    use PDF::API2;

    my ( $item_info_ref, $tag, $requests_ref, $workdir ) = @_;
    my $add_label_ref = ($tag eq 'Disc') ? \&add_disc_label : \&add_book_label;

    my $local_filename = "";
    my $local_filename_with_path = "";

    for my $user (keys %{$requests_ref}) {

        for my $date (keys %{$requests_ref->{$user}} ) {

            for my $period ( keys %{$requests_ref->{$user}{$date}} ) {

				#local name should be connected to what LabelSet thinks it is.  Hmm...
				# there needs to be one file for book and one for disc?
				# also they need to not clobber each other with multiple people working at the same time
				#TODO: this is nasty
				my @foo = sort @{ $requests_ref->{$user}{$date}{$period} };
				my $bar = scalar @foo ;
				my $baz = $foo[0]; #file name will be based on first barcode in the file
				my $qux = $baz->{'itemid'};

				$local_filename = $tag.".".$qux.".pdf";
                $local_filename_with_path = File::Spec->catfile($workdir, $local_filename);

                my $pdf = PDF::API2->new( '-file' => $local_filename_with_path );
                my ($ss, $mm, $hh, $DD, $MM, $YY, $isdst) = (localtime)[0,1,2,3,4,5,8];
                $pdf->info(
                        'Author'       => $user,
                        'CreationDate' => sprintf("D:%04d%02d%02d%02d%02d%02d-%02d'00'", 1900+$YY, 1+$MM, $DD, $hh, $mm, $ss, $isdst?4:5),
                        'Creator'      => $0,
                        'Title'        => sprintf("%s Labels · %s · %s", $tag, $date, $period),
                        'Subject'      => 'The Public Library of Cincinnati and Hamilton County',
                        'Keywords'     => 'label labels title call number callnumber barcode spine ownership',
                );

                my $fonts_ref = {
					#symphony was latin1, sierra is utf8
                    #'normal' => $pdf->corefont( 'Helvetica',      '-encoding' => 'latin1' ),
                    #'bold'   => $pdf->corefont( 'Helvetica-Bold', '-encoding' => 'latin1' ),
                    'helvetica' => $pdf->corefont( 'Helvetica',      '-encoding' => 'utf8' ),
                    'helveticabold'   => $pdf->corefont( 'Helvetica-Bold', '-encoding' => 'utf8' ),


                    #this font contains more foreign characters
                    #RHEL5
                    #'normal' 		=> $pdf->ttfont( '/usr/share/fonts/dejavu-lgc/DejaVuLGCSansCondensed.ttf' , '-encoding' => 'utf8' ),
                    #'bold' 	=> $pdf->ttfont( '/usr/share/fonts/dejavu-lgc/DejaVuLGCSansCondensed-Bold.ttf' , '-encoding' => 'utf8' ),
                    #UBUNTU trusty
                    #'normal' 		=> $pdf->ttfont( '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansCondensed.ttf' , '-encoding' => 'utf8' ),
                    #'bold' 	=> $pdf->ttfont( '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansCondensed-Bold.ttf' , '-encoding' => 'utf8' ),
                    #'normal' => $pdf->corefont( 'Helvetica',      '-encoding' => 'utf8' ),
                    #'bold'   => $pdf->corefont( 'Helvetica-Bold', '-encoding' => 'utf8' ),
                    #LOCAL
                    'normal' => $pdf->ttfont( './fonts/dejavu-lgc-fonts-ttf-2.34/ttf/DejaVuLGCSansCondensed.ttf' , '-encoding' => 'utf8' ),
                    'bold' => $pdf->ttfont( './fonts/dejavu-lgc-fonts-ttf-2.34/ttf/DejaVuLGCSansCondensed-Bold.ttf' , '-encoding' => 'utf8' ),
                };

                my $label_count = 0;
                my @labels = ();

                #Sort the labels
                @labels = sort { $a->{'time'} cmp $b->{'time'} || compare_itemids($a->{'itemid'}, $b->{'itemid'}) } @{ $requests_ref->{$user}{$date}{$period} };

                for my $request_ref ( @labels ) {
                    my $itemid = $request_ref->{'itemid'};
                    my $time   = $request_ref->{'time'};
                    my $pieces = $request_ref->{'pieces'};
                    $add_label_ref->($pdf, $fonts_ref, $item_info_ref, { 'itemid'=>$itemid , 'user'=>$user , 'date'=>$date , 'time'=>$time, 'piece'=>$_ }) foreach (1..$pieces);
                    $label_count += $pieces;
                }
                $pdf->save;
                $pdf->end();
            }
        }
    }
    #TODO: return the filename here?
    return $local_filename;
}

sub add_disc_label {
	#------------------------------------
	#
	# Creates an AV label
	#
	#------------------------------------

    use PDF::API2;
    #use Sequoia::Floating;
    use constant in => 1 / 72; # 1 inch = 72 points
    use constant pt => 1;
    my ($pdf, $fonts_ref, $item_info_ref, $req_ref) = @_;

    my %this_items = %{ $item_info_ref->{ $req_ref->{'itemid'} } };
    my %font = %{ $fonts_ref };
    my $middot = chr(183);

    my $page = $pdf->page;
    $page->mediabox( 4.07/in, 4.11/in );
    $page->cropbox( 0.04/in, 0.09/in, 4.04/in, 4.09/in );

    my $gfx  = $page->gfx;
#    draw_disc_stickers($gfx) if $req_ref->{'user'} eq 'XDBADEV';

    #Header
    $this_items{'disc_pieces'} .= '*' if ($this_items{'book_pieces'} > 0);
    $gfx->textlabel( 14/pt, 284/pt, $font{'bold'},  8/pt, join(" $middot ", $this_items{'icode1'}, $req_ref->{'user'}, $req_ref->{'date'}, $req_ref->{'time'}, $req_ref->{'piece'}.'/'.$this_items{'disc_pieces'}) );
    fit_text($gfx,  14/pt, 272/pt, $font{'bold'},  8/pt, $this_items{'title'}, 150/pt, {'-elipsis' => '...'});

    #Ownership Label 1/2
    $gfx->textlabel( 172/pt, 100/pt, $font{'helvetica'},  7/pt, 'The Public Library', '-align' => 'center' );  #+41pt
    $gfx->textlabel( 172/pt,  92/pt, $font{'helvetica'},  7/pt, 'of Cincinnati and',  '-align' => 'center' );  #+33pt
    $gfx->textlabel( 172/pt,  84/pt, $font{'helvetica'},  7/pt,  'Hamilton County',   '-align' => 'center' );  #+25pt
    $gfx->textlabel( 172/pt,  59/pt, $font{'helveticabold'}, 24/pt, $this_items{'agency'}, '-align' => 'center' );  #base
    if ( says_floating('libr'=>$this_items{'libr'}, 'ityp'=>$this_items{'ityp'}, 'ict1'=>$this_items{'ict1'}, 'locn'=>$this_items{'locn'}) ) {
        $gfx->textlabel( 172/pt, 40/pt, $font{'helveticabold'}, 14/pt, 'Floating', '-align' => 'center' );  #loan period
    }

    #Ownership Label 2/2
    $gfx->textlabel( 251/pt, 100/pt, $font{'helvetica'},  7/pt, 'The Public Library', '-align' => 'center' );  #+41pt
    $gfx->textlabel( 251/pt,  92/pt, $font{'helvetica'},  7/pt, 'of Cincinnati and',  '-align' => 'center' );  #+33pt
    $gfx->textlabel( 251/pt,  84/pt, $font{'helvetica'},  7/pt,  'Hamilton County',   '-align' => 'center' );  #+25pt
    $gfx->textlabel( 251/pt,  59/pt, $font{'helveticabold'}, 24/pt, $this_items{'agency'}, '-align' => 'center' );  #base
    if ( says_floating('libr'=>$this_items{'libr'}, 'ityp'=>$this_items{'ityp'}, 'ict1'=>$this_items{'ict1'}, 'locn'=>$this_items{'locn'}) ) {
        $gfx->textlabel( 251/pt, 40/pt, $font{'helveticabold'}, 14/pt, 'Floating', '-align' => 'center' );  #loan period
    }

    if ( $this_items{'ict1'} eq 'VIDEO-VHS' ) {
        #Call/Copy Label for spine
        my @call_lines = split /[ ]+/, $this_items{'callnum'};
        push @call_lines, $this_items{'copy'};
        my $text_line = 176;
        CALL_LINE:
        for my $line (@call_lines) {
            fit_text($gfx, 43/pt, $text_line/pt, $font{'bold'},  10/pt, $line, 50/pt, { '-align' => 'center', '-atom' => 'word'});
            $text_line -= 10;
            last CALL_LINE if $text_line < 112;
        }
    }
    elsif ( $this_items{'ict1'} eq 'PLAYAWAY' ) {
        #One-Line Labels
        fit_text($gfx,  88/pt, 242/pt, $font{'normal'},  8/pt, $this_items{'title'}, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'} );
        fit_text($gfx,  88/pt, 217/pt, $font{'normal'},  8/pt, $this_items{'callnum'}.' '.$this_items{'copy'}, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'} );

        #Small Ownership Label
        $gfx->textlabel( 43/pt, 181/pt, $font{'helvetica'},  6/pt, 'The Public Library', '-align' => 'center' );
        $gfx->textlabel( 43/pt, 174/pt, $font{'helvetica'},  6/pt, 'of Cincinnati and',  '-align' => 'center' );
        $gfx->textlabel( 43/pt, 167/pt, $font{'helvetica'},  6/pt,  'Hamilton County',   '-align' => 'center' );
        $gfx->textlabel( 43/pt, 147/pt, $font{'helveticabold'},   20/pt, $this_items{'agency'}, '-align' => 'center' );
    }
    else {
        #Initial Label
        if ( $this_items{'callnum'} =~ / [ ] [a-z]* ([A-Z]) [a-zA-Z]* [0-9]+ [a-z]? /xms ) {
            $gfx->textlabel( 43/pt, 148/pt, $font{'helveticabold'}, 48/pt, $1, '-align' => 'center' );
        }

        #One-Line Labels
        fit_text($gfx,  88/pt, 242/pt, $font{'normal'},  8/pt, $this_items{'title'}, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'} );
        fit_text($gfx,  88/pt, 217/pt, $font{'normal'},  8/pt, $this_items{'title'}, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'} );

        #Hub Label
        $gfx->textlabel(  65.5/pt, 105/pt, $font{'helvetica'},  6/pt, 'The Public Library of', '-align' => 'center' );
        $gfx->textlabel(  65.5/pt,  98/pt, $font{'helvetica'},  6/pt, 'Cincinnati & Hamilton Co.', '-align' => 'center' );
        $gfx->textlabel(  25  /pt,  63/pt, $font{'helveticabold'},  8/pt, $this_items{'agency'}, '-align' => 'center' );
        $gfx->textlabel( 105  /pt,  63/pt, $font{'helveticabold'},  8/pt, $this_items{'copy'}  , '-align' => 'center' );
        #print "hub label copy:  ".$this_items{'copy'}."\n";
        #print "hub label piece: ".$req_ref->{'piece'}."\n";

        #put the call number on the hub sticker
        $gfx->textstart;
        $gfx->font($font{'bold'}, 6/pt);
        my $hubcall = $this_items{'callnum'};
        if (length $this_items{'author'} == 0) {
            $hubcall .= ' ' . $this_items{'title'} if (
                ($this_items{'callnum'} !~ /^(?:j?CD|PL)-/i)
                and ( ($this_items{'ict1'} eq 'CD-BOOK') or ($this_items{'ict1'} eq 'CASS-BOOK') or ($this_items{'callnum'} =~ / jfiction | easy /ixms) )
            );
        }
        else {
            $hubcall .= ' ' . $this_items{'author'} if (
                ($this_items{'callnum'} !~ /^(?:j?CD|PL)-/i)
                and ( ($this_items{'ict1'} eq 'CD-BOOK') or ($this_items{'ict1'} eq 'CASS-BOOK') or ($this_items{'callnum'} =~ / fiction | easy /ixms) )
            );
        }

        if ($gfx->advancewidth($hubcall) < 76) {
            #all on one line
            $gfx->translate( 66/pt, 29/pt );
            $gfx->text_center($hubcall);
        }
        else {
            #upper line
            my @words = split / [ ]+ /xms, $hubcall;
            my $line = shift @words;
            while ( $words[0] && ($gfx->advancewidth("$line $words[0]") < 78) ) {
                $line .= ' '.shift @words;
            }
            $gfx->translate( 66/pt, 32/pt );
            $gfx->text_center($line);

            #lower line
            if ($words[0]) {
                my $line = shift @words;
                while ( $words[0] && ($gfx->advancewidth("$line $words[0]") < 60) ) {
                    $line .= ' '.shift @words;
                }
                $gfx->translate( 66/pt, 23/pt );
                $gfx->text_center($line);
            }

        }
        $gfx->textend;
    }

    #put up to five lines on the spine label
    my @spine_lines = get_spine_lines(\%this_items);
    my $baseline = 268;
    SPINE_LINE:
    for my $line ( @spine_lines ) {
        fit_text($gfx, 176/pt, $baseline/pt, $font{'bold'},  12/pt, $line, 108/pt, {'-atom' => 'word'});
        $baseline -= 14;
        last SPINE_LINE if $baseline < 212;
    }

    #print the barcode
    my $bc =  $pdf->xo_3of9(
            -font   => $font{'normal'}, # the font to use for text
            -fnsz   => 12,         # (f)o(n)t(s)i(z)e
            -code   => $this_items{'barcode'},    # the code of the barcode
            -umzn   => 10,         # (u)pper (m)ending (z)o(n)e [extension of the bars at the top]
            -lmzn   => 12,         # (l)ower (m)ending (z)o(n)e [the bit where the code digits go]
            -zone   => 26,         # height (zone) of bars
            -quzn   => 10,         # (qu)iet (z)o(n)e [bottom and left margins]
            -ofwt   => 0.01,       # (o)ver(f)low (w)id(t)h
    );
    $gfx->formimage($bc, 96/pt, 132/pt, 0.7);
}

sub add_book_label {
	#------------------------------------
	#
	# Creates a Book label
	#
	#------------------------------------

    use PDF::API2;
    #use Sequoia::Floating;
    use constant in => 1 / 72; # 1 inch = 72 points
    use constant pt => 1;
    my ($pdf, $fonts_ref, $item_info_ref, $req_ref) = @_;

    my %this_items = %{ $item_info_ref->{ $req_ref->{'itemid'} } };
    my %font = %{ $fonts_ref };
    my %use_callnum       = map { $_ => 1 } qw (CASS-BKREF CASS-BOOK CASS-MUREF CASS-MUSIC JCAS-MUSIC JCASS-BOOK MAP MICROFICHE MICROFILM PLAYAWAY TPLAYAWAY JPLAYAWAY FJPLAYAWAY FPLAYAWAY FTPLAYAWAY );
    %use_callnum = map { $_ => 1 } qw( 62 60 67 65 66 61 144 145 146 90 91 92 );
    my $middot = chr(183);

    my $page = $pdf->page;
    $page->mediabox( 4.26/in, 3.12/in );
    $page->cropbox( 0.13/in, 0.06/in, 4.13/in, 3.06/in );

    my $gfx  = $page->gfx;
#    draw_book_stickers($gfx) if $req_ref->{'user'} eq 'XDBADEV';

    #Header
    $this_items{'book_pieces'} .= '*' if ($this_items{'disc_pieces'} > 0);
    $gfx->textlabel( 25/pt, 209/pt, $font{'bold'},  8/pt, join(" $middot ", $this_items{'icode1'}, $req_ref->{'user'}, $req_ref->{'date'}, $req_ref->{'time'}, $req_ref->{'piece'}.'/'.$this_items{'book_pieces'}) );
    fit_text($gfx, 25/pt, 197/pt, $font{'bold'},  8/pt, $this_items{'title'}, 190/pt, {'-elipsis' => '...'});

    #print the barcode
    my $bc =  $pdf->xo_3of9(
            -font   => $font{'normal'}, # the font to use for text
            -fnsz   => 12,         # (f)o(n)t(s)i(z)e
            -code   => $this_items{'barcode'},    # the code of the barcode
            -umzn   => 10,         # (u)pper (m)ending (z)o(n)e [extension of the bars at the top]
            -lmzn   => 12,         # (l)ower (m)ending (z)o(n)e [the bit where the code digits go]
            -zone   => 26,         # height (zone) of bars
            -quzn   => 10,         # (qu)iet (z)o(n)e [bottom and left margins]
            -ofwt   => 0.01,       # (o)ver(f)low (w)id(t)h
    );
    $gfx->formimage($bc, 35/pt, 135/pt, 0.7);

    # Add 'chpl.org' text above the barcode, attempting centering manually
    my $text = 'CHPL.org';
    my $font_size = 8; # Smaller font size

    # Calculate the starting X-coordinate for the text to approximately center it over the barcode
    # Without knowing the exact width of "CHPL.org", we approximate by adjusting this manually
    # my $text_start_x = $barcode_center_x - ($barcode_scaled_width / 4); # Adjust this value as needed
    my $text_start_x = 35/pt + 72/pt;  # 70/pt half the width of the barcode?
    my $text_y_position = 178/pt; # Adjust y-coordinate as needed for positioning above the barcode

    # $gfx->textlabel($text_x_position, $text_y_position, $font{'normal'}, $font_size, $text, '-align' => 'center');
    $gfx->textlabel($text_start_x, $text_y_position, $font{'normal'}, $font_size, $text, '-align' => 'center');

    #Ownership Label
    $gfx->textlabel( 258/pt, 180/pt, $font{'helvetica'},  7/pt, 'Cincinnati &',   '-align' => 'center' );
    $gfx->textlabel( 258/pt, 172/pt, $font{'helvetica'},  7/pt, 'Hamilton County', '-align' => 'center' );
    $gfx->textlabel( 258/pt, 164/pt, $font{'helvetica'},  7/pt, 'Public Library', '-align' => 'center' );
    $gfx->textlabel( 258/pt, 156/pt, $font{'helvetica'},  7/pt, 'CHPL.org', '-align' => 'center' );
    # $gfx->textlabel( 258/pt, 139/pt, $font{'helveticabold'}, 24/pt, $this_items{'agency'}, '-align' => 'center' );
    $gfx->textlabel( 258/pt, 135/pt, $font{'helveticabold'}, 24/pt, $this_items{'agency'}, '-align' => 'center' );
    if ( says_floating('libr'=>$this_items{'libr'}, 'ityp'=>$this_items{'ityp'}, 'ict1'=>$this_items{'ict1'}, 'locn'=>$this_items{'locn'}) ) {
        $gfx->textlabel( 258/pt, 120/pt, $font{'helveticabold'}, 14/pt, 'Floating', '-align' => 'center' );
    }

    # RV DEBUG
    # print STDERR "agency: $this_items{'agency'}\n";

    my $line_text = $use_callnum{$this_items{'ityp'}} ? join(' ', $this_items{'callnum'}, $this_items{'copy'}, $this_items{'agency'}) : $this_items{'title'};
    fit_text($gfx, 95/pt, 96/pt, $font{'normal'},  8/pt, $line_text, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'});
    fit_text($gfx, 95/pt, 71/pt, $font{'normal'},  8/pt, $line_text, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'});
    fit_text($gfx, 95/pt, 47/pt, $font{'normal'},  8/pt, $line_text, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'});
    fit_text($gfx, 95/pt, 22/pt, $font{'normal'},  8/pt, $line_text, 150/pt, {'-align' => 'center', '-elipsis' => '...', '-atom' => 'word'});

    #put up to five lines on the spine label
    my @spine_lines = get_spine_lines(\%this_items);
    my $baseline = 78;
    SPINE_LINE:
    for my $line ( @spine_lines ) {
        fit_text($gfx, 187/pt, $baseline/pt, $font{'bold'},  12/pt, $line, 100/pt, {'-atom' => 'word'});
        $baseline -= 14;
        last SPINE_LINE if $baseline < 22/pt;
    }

}

sub get_spine_lines {
	#------------------------------------
	#
	# For a given item, determine what appears on the spine
	#
	#------------------------------------

    my $item_ref = shift;
    my @results = ($item_ref->{'callclass'} eq 'SUDOC') ? (split / [:]+ /xms, $item_ref->{'callnum'}, 5) : (split / [ ]+ /xms, $item_ref->{'callnum'}, 5);

    unshift @results, 'CD-ROM' if $item_ref->{'ict1'} eq 'CD_ROM';  #ict1 = CD-ROM, bcode2 = m
    unshift @results, 'DVD'    if ( ($item_ref->{'ict1'} eq 'VIDEO-DVD') and ($item_ref->{'callnum'} !~ /^R?DVD/) );  #ict1 = VIDEO-DVD, bcode2 = g
    unshift @results, 'TEEN' if ($item_ref->{'ict2'} eq 'TEEN' && $item_ref->{'ict1'} ne 'VIDEO-DVD');  #don't add 'TEEN' for DVD's in TEENSPOT

    if (length $item_ref->{'author'} == 0) {
        push @results, $item_ref->{'browse'} if (
            ($item_ref->{'callnum'} !~/^j?(?:CD|PL)-/i)
            and ( ($item_ref->{'ict1'} eq 'CD-BOOK') or ($item_ref->{'ict1'} eq 'CASS-BOOK')  or ($item_ref->{'ict1'} eq 'PLAYAWAY') or ($item_ref->{'callnum'} =~ / fiction | easy /ixms) )
            and ( $item_ref->{'callnum'} !~ /CD-Spoken/ixms )
        );
    }
    else {
        push @results, $item_ref->{'author'} if (
            ($item_ref->{'callnum'} !~ /^j?(?:CD|PL)-/i)
            and ( ($item_ref->{'ict1'} eq 'CD-BOOK') or ($item_ref->{'ict1'} eq 'CASS-BOOK' or ($item_ref->{'ict1'} eq 'PLAYAWAY') ) or ($item_ref->{'callnum'} =~ / fiction | easy /ixms) )
        );
    }
    push @results, $item_ref->{'copy'} if $spine_gets_copy{$item_ref->{'ict1'}};
    unshift @results, 'Reference' if $item_ref->{'ityp'} eq '18';  #ityp = GOVDOC-REF, ityp_code = 18

    return @results;
}

sub draw_disc_stickers {
    use PDF::API2;
    use constant in => 1 / 72; # 1 inch = 72 points
    my $gfx = shift;
    $gfx->save;

    $gfx->fillcolor('lightgrey');
    $gfx->rect( 0.00/in, 0.00/in, 4.07/in, 4.11/in );
    $gfx->fill;

    $gfx->fillcolor('white');
    rounded_rect($gfx, 0.04/in, 0.09/in, 4.00/in, 4.00/in, 0.22/in);
    $gfx->fill;

    $gfx->strokecolor('lightgrey');

    #Cassette labels
    oneline_sticker($gfx, 0.12/in, 3.27/in, 2.2/in, 0.26/in);
    oneline_sticker($gfx, 0.12/in, 2.93/in, 2.2/in, 0.26/in);

    #spine
    rounded_rect($gfx, 2.38/in, 2.84/in, 1.61/in, 1.11/in, 0.13/in);

    #Initial
    rounded_rect($gfx, 0.22/in, 1.93/in, 0.75/in, 0.75/in, 0.13/in);

    #barcode
    rounded_rect($gfx, 1.24/in, 1.76/in, 2.75/in, 0.81/in, 0.13/in);

    #hub
    $gfx->circle( 0.91/in, 0.93/in, 0.75/in );
    $gfx->circle( 0.91/in, 0.93/in, 0.37/in );

    #ownership 1
    rounded_rect($gfx, 1.89/in, 0.34/in, 1.00/in, 1.29/in, 0.13/in);

    #ownership 2
    rounded_rect($gfx, 2.98/in, 0.34/in, 1.00/in, 1.29/in, 0.13/in);

    $gfx->stroke;

    $gfx->restore;
    return;
}

sub draw_book_stickers {
    use PDF::API2;
    use constant in => 1 / 72; # 1 inch = 72 points
    my $gfx = shift;
    $gfx->save;

    $gfx->fillcolor('lightgrey');
    $gfx->rect( 0.00/in, 0.00/in, 4.26/in, 3.12/in );
    $gfx->fill;

    $gfx->fillcolor('white');
    rounded_rect($gfx, 0.13/in, 0.06/in, 4.00/in, 3.00/in, 0.22/in);
    $gfx->fill;

    $gfx->strokecolor('lightgrey');

    #barcode label
    rounded_rect($gfx, 0.20/in, 1.81/in, 2.75/in, 0.78/in, 0.13/in);

    #Ownership label
    rounded_rect($gfx, 3.09/in, 1.46/in, 0.99/in, 1.29/in, 0.13/in);

    #Spine label
    rounded_rect($gfx, 2.49/in, 0.21/in, 1.59/in, 1.1/in, 0.13/in);

    #cassette labels
    oneline_sticker($gfx, 0.22/in, 1.24/in, 2.2/in, 0.26/in);
    oneline_sticker($gfx, 0.22/in, 0.90/in, 2.2/in, 0.26/in);
    oneline_sticker($gfx, 0.22/in, 0.56/in, 2.2/in, 0.26/in);
    oneline_sticker($gfx, 0.22/in, 0.22/in, 2.2/in, 0.26/in);

    $gfx->stroke;

    $gfx->restore;
    return;
}

sub rounded_rect {
    use PDF::API2;
    my ($gfx, $left, $bottom, $width, $height, $radius) = @_;

    $gfx->save;
    $gfx->move(  $left+$radius, $bottom );
    $gfx->line(  $left+$width-$radius, $bottom );
    $gfx->bogen( $left+$width-$radius, $bottom, $left+$width, $bottom+$radius, $radius, 0, 0, 1 );
    $gfx->line(  $left+$width, $bottom+$height-$radius );
    $gfx->bogen( $left+$width, $bottom+$height-$radius, $left+$width-$radius, $bottom+$height, $radius, 0, 0, 1 );
    $gfx->line(  $left+$radius, $bottom+$height );
    $gfx->bogen( $left+$radius, $bottom+$height, $left, $bottom+$height-$radius, $radius, 0, 0, 1 );
    $gfx->line(  $left, $bottom+$radius );
    $gfx->bogen( $left, $bottom+$radius, $left+$radius, $bottom, $radius, 0, 0, 1 );
    $gfx->restore;

    return;
}

sub oneline_sticker {
    use PDF::API2;
    my ($gfx, $left, $bottom, $width, $height) = @_;

    my $radius = $height / 2;

    $gfx->save;
    $gfx->move(  $left+$radius, $bottom );
    $gfx->line(  $left+$width-$radius, $bottom );
    $gfx->bogen( $left+$width-$radius, $bottom, $left+$width, $bottom+$radius, $radius, 0, 0, 1 );
    $gfx->bogen( $left+$width, $bottom+$radius, $left+$width-$radius, $bottom+$height, $radius, 0, 0, 1 );
    $gfx->line(  $left+$radius, $bottom+$height );
    $gfx->bogen( $left+$radius, $bottom+$height, $left+$radius, $bottom, $radius, 0, 0, 1 );
    $gfx->restore;

    return;
}

sub fit_text {
    use PDF::API2;
    my ($obj, $x, $y, $face, $size, $text, $width, $opt_ref) = @_;

    $opt_ref->{'-align'} = 'left' unless exists $opt_ref->{'-align'};
    $opt_ref->{'-elipsis'} = '' unless exists $opt_ref->{'-elipsis'};
    $opt_ref->{'-atom'} = 'character' unless exists $opt_ref->{'-atom'};

    $obj->save;
    $obj->textstart;

    $obj->font($face, $size);
    $obj->translate( $x, $y );

    if ($obj->advancewidth($text) > $width) {
        my $elipsis = $opt_ref->{'-elipsis'} ;
        if ( $opt_ref->{'-atom'} eq 'character') {
            #trim character-by-character
            while ($obj->advancewidth("$text$elipsis") > $width) {
                substr($text, -1, 1, '');
            }
        }
        else {
            #trim word-by-word
            #Need to Fix: if the last word is longer than the width, it will overflow.
            my @words = split /[ ]+/xms, $text;
            $text = shift @words;
            while ( $words[0] && $obj->advancewidth($text . ' ' . $words[0] . $elipsis) <= $width ) {
                $text .= ' ' . shift @words;
            }
        }
        $text .= $elipsis;
    }

    if ($opt_ref->{'-align'} eq 'center') {
        $obj->text_center($text);
    }
    else {
        $obj->text($text);
    }

    $obj->textend;
    $obj->restore;
    return;
}

sub compare_itemids {
    my ($alpha, $beta) = @_;

    my ($catkey1, $callseq1, $copy1) = $alpha =~ /^(\d+)-(\d{1,3})(\d{3})$/;
    my ($catkey2, $callseq2, $copy2) = $beta  =~ /^(\d+)-(\d{1,3})(\d{3})$/;

    if ($catkey1 && $catkey2) {
        return $catkey1 <=> $catkey2 || $callseq1 <=> $callseq2 || $copy1 <=> $copy2;
    }

    return $alpha cmp $beta;
}

1;
