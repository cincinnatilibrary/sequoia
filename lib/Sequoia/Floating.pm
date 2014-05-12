package Sequoia::Floating;

use 5.008007;
use warnings;
use strict;
use Carp;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    is_floating
    should_float
    says_floating
);
our @EXPORT = qw( says_floating);

#sierra-done
my %ityp_is_floating  = map {$_=>1} qw( FATLAS FBOOK FCASS-BOOK FCD-BOOK FCD-MUSIC FJATLAS FJBOOK FJCASS-BK FJCD-BOOK FJCD-MUSIC FJLARGEPRT FJPLAYAWAY FJSCORE FLARGEPRT FPLAYAWAY FSCORE FTBOOK FTCD-BOOK FTPLAYAWAY FVIDEO-NFE ); #symphony ityps
%ityp_is_floating 	  = map {$_=>1} qw( 1 3 5 21 23 158 160 );  #SIERRA: ityp code numbers.
my %ityp_can_float    = map {$_=>1} qw( CASS-BOOK JCASS-BOOK CD-BOOK JCD-BOOK TCD-BOOK LARGEPRINT JLARGEPRNT CD-MUSIC JCD-MUSIC PLAYAWAY JPLAYAWAY TPLAYAWAY VIDEO-NFEA ATLAS BOOK SCORE TBOOK JATLAS JBOOK JSCORE );  #symphony ityps
%ityp_can_float		  = map {$_=>1} qw( BOOK 0 2 4 20 22 60 61 70 71 72 77 78 90 91 92 101 157 159 );  #SIERRA: itype code numbers.

#sierra-done
my %libr_is_branch    = map {$_=>1} qw( ANDERSON AVONDALE BLUE_ASH BOND_HILL CHEVIOT CLIFTON COLL_HILL CORRYVILLE COVEDALE DEER_PARK DELHI_TWP ELMWOOD_PL FOREST_PRK GREEN_TWP GRNHILLS GROESBECK HARRISON HYDE_PARK LOVELAND MADEIRA MARIEMONT MDISONVLLE MIAMI_TWP MONFRT_HTS MTHEALTHY MTWASHNGTN NORWOOD NRCENTRAL NRSIDE OAKLEY PLSNT_RDGE PRICE_HILL READING SHARONVLLE STBERNARD SYMMES_TWP WALNUT_HLS WEST_END WSTWOOD WYOMING );  #symphony library
%libr_is_branch		  = map {$_=>1} qw( an av ba bh ch cl co cr cv dp dt ep fo ge gh gr ha hp lv ma mm md mn mo mt mw nw nr ns oa pl pr re sh sb sm wh wt ww wy );  #take the branch prefix from location_code
#%libr_is_branch		  = map {$_=>1} qw( 2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 33 34 35 36 37 38 39 40 41 42 );  #goes by agency number

#sierra-todo
my %locn_floats       = map {$_=>1} qw( BABFIC BABNFIC BADUAB BADUFIC BADUGRAPH BADUNONFIC BADUOVR BADUPBK BADUSERIES BAFRIAMER BAWARD BBIGBOOKS BBIO BBOARDBKS BCAREER BCD BCLASSFIC BCONCEPT BEARLYCHAP BEASY BEASYREAD BESOL BFANTASY BFOLKTALE BFORLANG BHISTFIC BHOLIDAY BINSPIRATL BJNFEADVD BJPLAYAWAY BJUVAB BJUVBIO BJUVCASS BJUVCD BJUVCDROM BJUVFIC BJUVGRAPH BJUVLGPRNT BJUVNEW BJUVNONFIC BJUVOVRFIC BJUVOVRNF BJUVPBK BJUVPOP BJUVSERIES BLGPRINT BLOCALINT BMYSTERY BNATIVAMER BNEW BNFEAANIME BNFEADOC BNFEATV BNFFILDVD BPARENTS BPLAYAWAY BROMANCE BSCIFAIR BSCIFIC BSEASON BSTACKS BSTAFFPICK BTEACHRES BTEEAB BTEEBIO BTEECD BTEEFIC BTEEGRAPH BTEENEW BTEENONFIC BTEEPBK BTEESERIES BTEST BTPLAYAWAY BTRAVEL BWESTERN ON-ORDER);  #symphony shelf locations

#written for sierra
sub locn_floats{
	my $locn = shift;
	my $location_code_4		= ( length $locn > 3 ) ? substr( $locn, 3, 1 ) : "";
	my $location_code_5		= ( length $locn > 4 ) ? substr( $locn, 4, 1 ) : "";
	my $shelf				= $location_code_4 . $location_code_5;
	
	#print "location: ".$locn." shelf: ".$shelf."\n";
	
	my %is_floating_shelf	= map { $_ => 1 } qw( oo aa ab af al an ao ar au bd bg bi c cb cc ce cf cg ch ci ch ck cl cm cn co cp cq cr cs cv cw cx cy cz d da dc df dm dr ds dt du eb ec er es f fc ff fh fl fm fp fr fs fw gn ho in kl l lf ln mc nf nr od  pb pl ps pu sb se sf sl ss st tv v vf vm );
	
	return 1 if $is_floating_shelf{$shelf};

	#print "shelf floats = 0\n";

	return 0;
}
	
#says_floating is used to put the word "Floating" on item labels, therefore needs to be converted for Sierra
# consider moving this function into Labels.pm
sub says_floating {
    my %param = @_;
    my $ityp = $param{'ityp'} || '';  #these are sierra ityp numbers
    my $ict1 = $param{'ict1'} || '';  #these get translated to their old symphony names
    my $libr = $param{'libr'} || '';  #these are sierra agency numbers
    my $locn = $param{'locn'} || '';  #these are sierra shelf locations??

	my $location_code_1_2 	= substr( $locn, 0, 2 );
	$libr = $location_code_1_2;

    #print "libr: ".$libr."\n";
    #print "  locn: ".$location_code_1_2."\n";
    #print "  ict1: ".$ict1."\n";
    #print "  ityp: ".$ityp."\n";

    return 0 if $ict1 eq 'VIDEO-VHS';
    
    #return 1 if $libr eq 'MAIN' && $ityp eq 'FVIDEO-NFE';
    # SIERRA: MAIN = 1; FVIDEO-NFE = "DVD" = "DVD/Videocassette" = "101"
    return 1 if $libr eq '1' && $ityp eq '101';  
    	
	if ($location_code_1_2 eq '1p' )
	{
		return 0 if $ityp eq '100';
		return 1 if $ityp eq '101';
		return 0;
	}

    
    if ($libr_is_branch{$libr}) {
		#print "libr is branch.\n";
        return 1 if ($ityp_is_floating{$ityp});
        #print "ityp isn't floating.\n";
        return 1 if $ityp_can_float{$ityp} && locn_floats($locn);
    }

	#print "says floating = 0.\n";
    return 0;
}

1;
