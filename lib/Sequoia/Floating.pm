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

#PLCH specific maps
my %ityp_is_floating  = map {$_=>1} qw( 1 3 5 21 23 158 160 );  #SIERRA: ityp code numbers.
my %ityp_can_float    = map {$_=>1} qw( BOOK 0 2 4 20 22 60 61 70 71 72 77 78 90 91 92 101 157 159 );  #SIERRA: itype code numbers.
my %libr_is_branch    = map {$_=>1} qw( an av ba bh ch cl co cr cv dp dt ep fo ge gh gr ha hp lv ma mm md mn mo mt mw nw nr ns oa pl pr re sh sb sm wh wt ww wy );  #take the branch prefix from location_code

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
    my $locn = $param{'locn'} || '';  #these are sierra shelf locations??

	my $location_code_1_2 	= substr( $locn, 0, 2 );
	$libr = $location_code_1_2;

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

1;
