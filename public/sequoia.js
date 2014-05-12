// Used by bib.html, barcodes.html, and replace.html to interact with mod_perl json services on ilsaux.plch.net
// Dave Menninger - 2013

//------------------------------------------------------------
// used by bib.html to look up barcodes for a given bib number
//------------------------------------------------------------
function find_barcodes()
{
	var bibnumber = '';
	bibnumber = $( '#bibNumInput').val(); //must include the b prefix, may or may not include check-digit TODO: write a validator?
	bibnumber = bibnumber.replace(/\s+/g, '');  //remove whitespace
	var icode1 = '';
	icode1 = $( '#icode1NumInput').val(); //either all, or a number between 0 - 999

	var my_bc_list = '';

	//reset display to blank
	$( '#myList' ).html( my_bc_list );
	$( '#bibTitle p:first' ).html( '' );
	$( "#makeLabels" ).hide();

	//get JSON-formatted list of barcodes for this bibnumber
	// this is talking to BibItems.pm
	var request_url = "/bibitems?bibnumber="+bibnumber+"&icode1="+icode1;
	$.getJSON( request_url, function( resp ) 
	{
		//there should only be one key
		//this is a dumb way to find out what it is
		$.each( resp, function( key, value ) 
		{
			bibnumber = key;
		});

		//save barcodes into localStorage for later use
		localStorage.setItem('barcodes', JSON.stringify( resp[bibnumber].barcodes ) );
		//TODO: remove this from localStorage at some point with removeItem

		var items_found = '0';
		if (typeof resp[bibnumber].num_items_found != 'undefined') {
			items_found = resp[bibnumber].num_items_found;
		}

		//display title
		$( '#bibTitle p:first' ).html( '<b>' + resp[bibnumber].title + '</b>' + '<br/> items found: ' + items_found);

		var times_barcode_seen = {};
		var array_of_dupes = [];

		//add barcodes to the list
		$.each( resp[bibnumber].barcodes, function(b,bc)
		{
			if ( typeof times_barcode_seen[bc] != 'undefined' )
			{
				//we've seen it once before
				times_barcode_seen[bc] += 1;
				//console.log("dupe: " + bc);
				array_of_dupes.push( bc );
				//my_bc_list += '<li>' + bc + '</li>';
				my_bc_list += '<li class="itemnotfound"> &#10005; ';
				my_bc_list += bc;
				my_bc_list += ' &mdash; Item has duplicate barcode.';
			}
			else
			{
				//first time seeing it
				times_barcode_seen[bc] = 1;
				my_bc_list += '<li>' + bc + '</li>';
			}
		});

		var dupe_warning_message = "This title contains duplicate barcodes!";

		if( array_of_dupes.length > 0 )
		{
			$( '#bibTitle p:first' ).append( "<br/>"  + dupe_warning_message )
			my_bc_list += "<br/>" + dupe_warning_message;
			alert( dupe_warning_message );
		}
		
		//show the result list
		$( "#myBarcodeList" ).html( my_bc_list );
		$( "#makeLabels" ).show();
		
		//focus on the button, so you can just hit enter again
		$( "#makeButton" ).focus();
		
		//hide the previous pdf link if there was one
		$( "#myPdfList" ).hide();

	});
} 

//------------------------------------------------------------
// - used by barcodes.html to take the list of barcodes entered by the user and validate it
//------------------------------------------------------------
function add_barcodes()
{
	//reset display to blank
	$( '#myList' ).html( my_bc_list );
	$( "#makeLabels" ).hide();

	//get the list of barcodes the user entered and clean it up
	var my_bc_list = '';
	my_bc_list = $( '#barcodeInputTextArea').val();
	my_bc_list = my_bc_list.replace(/\s+/g, ',');  //remove whitespace, replace with commas
	my_bc_list = my_bc_list.replace(/,,+/g, ','); //dedupe commas
	my_bc_list = my_bc_list.replace(/,$/g, ''); //trailing comma
	my_bc_list = my_bc_list.toUpperCase(); //because whatever

	//parse the textareinput into a json array
	var array_of_bc = my_bc_list.split(",");

	//check the barcodes against this API to see if they are real:
	// talk to the ItemsInfo.pm service
	//var urlbase = '/itemsinfo?barcodes=';
	//var url = urlbase + my_bc_list;
	var bc_list_html = '';	
	var array_of_good_bc = [];
	//$.getJSON( url, function( resp )

	var url = '/itemsinfo';
	var myData = {};

	myData.barcodes = my_bc_list;

	//this can take several minutes if hundreds of items are submitted
	//it might be good to change the pattern to submit the request into a queue and poll
	$.ajax(
	{
		url: url,
		type: 'POST',
		dataType: 'json',
		async: false,
		data: myData,
		success: function (resp)
		{
			//add barcodes to the html list
			for (var i = 0; i < array_of_bc.length; i++) 
			{
				if( array_of_bc[i] != '' ) //avoid adding nulls, this should be redundant
				{				
					if (typeof resp[ array_of_bc[i] ] != 'undefined') 
					{
						bc_list_html += '<li class="itemfound">  &#10003; ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; ' + resp[ array_of_bc[i] ].title; // + ' &#8599; ';
						array_of_good_bc.push( array_of_bc[i] );
					}
					else
					{
						bc_list_html += '<li class="itemnotfound"> &#10005; ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; Item not found.';
					}
					bc_list_html += ' </li>';
				}
			}

			//save barcodes into localStorage for later use
			localStorage.setItem('barcodes', '[ "' + array_of_good_bc.join('" , "') + '"] '  );
			//localStorage.setItem('barcodes', '[ "' + array_of_bc.join('" , "') + '"] '  );
			//TODO: remove this from localStorage at some point with removeItem		

			//show the result html list
			$( "#myBarcodeList" ).html( bc_list_html );
			$( "#makeLabels" ).show();
		}
	});
	
	//focus on the make button, so you can just hit enter again
	$( "#makeButton" ).focus();
	
	//hide the previous pdf link if there was one
	$( "#myPdfList" ).hide();

} 

//------------------------------------------------------------
// used by both bib.html and barcodes.html to create a PDF of labels from a list of barcodes
//------------------------------------------------------------
function make_labels()
{	
	//pull saved list of barcodes from localStorage
	var barcodesstring = localStorage.getItem('barcodes');
	var parsedbarcodes = JSON.parse( barcodesstring );
	var commasepbarcodes = '';

	//build url string for labels webservice
	//there is probably a better way to do this
	//use join() ?
	$.each( parsedbarcodes, function(k,v)
	{
		commasepbarcodes += v;
		if( k < parsedbarcodes.length-1 )
		{
			commasepbarcodes += ',';
		}
	});

	//show a loading message in case getJSON takes a while
	$( '#myPdfList' ).html( '<li>Loading...</li>' );
	$( "#myPdfList" ).show();	

	//talk to the LabelSet.pm service
	//var urlbase = '/labels?barcodes=';
	//var url = urlbase + commasepbarcodes;


	var url = '/labels';
	var myData = {};

	myData.barcodes = commasepbarcodes;

	//request labels be made
	$.ajax(
	{
		url: url,
		type: 'POST',
		dataType: 'json',
		async: false,
		data: myData,
		success: function (resp)
		{
			//label files should now exist at this location:
			var bookpdflink = resp['bookpdf'];
			var discpdflink = resp['discpdf'];
			
			//how many labels did we get:
			var donelabels = resp['donelabels'];  //hmm, is this how many are in both files?
			
			//timestamp is when the request was received
			var timestamp = resp['timestamp'];
			
			//show a link to the pdf file and set focus to the first link, so you can just hit enter again to get it
			$( '#myPdfList' ).html( '' );
			if ( bookpdflink != '/pdf/')
			{
				//console.log ( bookpdflink );
				$( '#myPdfList' ).append( '<li> &#128215; Book: '+ timestamp + ' - <a id="myPdfLink1" target="_blank" href=' + bookpdflink +'>' + bookpdflink + '</a></li>');
			}
			if ( discpdflink != '/pdf/')
			{
				//console.log ( discpdflink );
				$( '#myPdfList' ).append( '<li> &#128191; Disc: '+ timestamp + ' - <a id="myPdfLink2" target="_blank" href=' + discpdflink +'>' + discpdflink + '</a></li>');
			}
			$( "#myPdf" ).show();
			$( '#myPdfLink1' ).focus();
		}
	});
	
}

$(document).ready(function(){
	$( "#barcodeInputTextArea" ).bind("keyup change input", function() {
		//check barcodes entered for potential problems

		var tooLong = 8000;
		var re_pattern = /^(\w|\s|,|-)+$/;

		var currentString = $( "#barcodeInputTextArea" ).val(); 

		if ( currentString.length > tooLong || !(re_pattern.test(currentString)) )
		{
			$( "#barcodeInputTextArea" ).addClass("inputBadShadow");
			//$( "#barcodeInputTextArea" ).after( "<br/>input is very long.  be patient." );
		}
		if ( currentString.length < tooLong && re_pattern.test(currentString) )
		{
			$( "#barcodeInputTextArea" ).removeClass("inputBadShadow")
		}

	});
});
