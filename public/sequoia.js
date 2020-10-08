// Used by bib.html, barcodes.html, and replace.html to interact with mod_perl json services on ilsaux.plch.net
// Dave Menninger - 2014

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
				console.log("dupe: " + bc);
				array_of_dupes.push( bc );
				//my_bc_list += '<li>' + bc + '</li>';
				my_bc_list += '<li class="text-danger"> &#10005; ';
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
						bc_list_html += '<li class="text-success">  &#10003; ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; ' + resp[ array_of_bc[i] ].title; // + ' &#8599; ';
						array_of_good_bc.push( array_of_bc[i] );
					}
					else
					{
						bc_list_html += '<li class="text-danger"> &#10005; ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; Item not found.';
					}
					bc_list_html += ' </li>';
				}
			}

			//save barcodes into localStorage for later use
			console.log('setting barcodes to localStorage... in add_barcodes()')
			localStorage.setItem('barcodes', '[ "' + array_of_good_bc.join('" , "') + '"] '  );

			// RV barcodes should now contain extra info, such as requesting location, and title so that we can use it on the lable:
			// for some reason, localstorage is where the barcodes are drawn from the submit the request
			
			// .. the information stored in:
			// /replacementrequests.json
			// e.g.:
			// {"A000054394499":{"reqestLocation":"bh","request_timestamp":"2020-09-16 10:33:25","title":"Moana"}}
			


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
	var commaseprequestlocations = '';

	//build url string for labels webservice
	//there is probably a better way to do this
	//use join() ?
	$.each( parsedbarcodes, function(k,v)
	{
		commasepbarcodes += v;

		// get the location from the barcode in localstorage:
		try {
			commaseprequestlocations += JSON.parse(localStorage.getItem(v)).reqestLocation;
		}
		catch (exception) { /* do nothing for now... i guess */}

		if( k < parsedbarcodes.length-1 )
		{
			commasepbarcodes += ',';
			commaseprequestlocations += ',';
		}
	});

	//show a loading message in case ajax takes a while
	$( '#myPdfList' ).html( '<progress>Loading...</progress>' );
	$( '#myPdfList' ).show();

	//talk to the LabelSet.pm service
	var url = '/labels';
	var myData = {};

	myData.barcodes = commasepbarcodes;

	myData.reqestLocations = commaseprequestlocations;

	console.log('myData:');
	console.log(myData);

	//request labels be made
	var promise1 = $.ajax({
		url: url,
		type: 'POST',
		dataType: 'json',
		async: false,
		data: myData
	});
	//this doesn't work how i expect:
	var promise2 = $( '#myPdfList' ).html( '<progress>Loading...</progress>' ).promise();

	$.when( promise1, promise2 ).done(
		function (resp)
		{
			//label files should now exist at this location:
			var bookpdflink = resp[0]['bookpdf'];
			var discpdflink = resp[0]['discpdf'];

			//how many labels did we get:
			var donelabels = resp[0]['donelabels'];  //hmm, is this how many are in both files?

			//timestamp is when the request was received
			var timestamp = resp[0]['timestamp'];

			//show a link to the pdf file and set focus to the first link, so you can just hit enter again to get it
			$( '#myPdfList' ).html( '' );
			if ( parsedbarcodes.length != donelabels )
			{
				$( '#myPdfList' ).append( '<li class="text-danger"> you asked for ' + parsedbarcodes.length + ' barcodes and got back ' + donelabels + ' pages.</li>' );
			}
			else
			{
				$( '#myPdfList' ).append( '<li class="text-success"> you asked for ' + parsedbarcodes.length + ' barcodes and got back ' + donelabels + ' pages.</li>' );
			}
			if ( bookpdflink != '/pdf/')
			{
				$( '#myPdfList' ).append( '<li> &#128215; Book: '+ timestamp + ' - <a id="myPdfLink1" target="_blank" href=' + bookpdflink +'>' + bookpdflink + '</a></li>');
			}
			if ( discpdflink != '/pdf/')
			{
				$( '#myPdfList' ).append( '<li> &#128191; Disc: '+ timestamp + ' - <a id="myPdfLink2" target="_blank" href=' + discpdflink +'>' + discpdflink + '</a></li>');
			}
			if ( donelabels > 0 )
			{
				$( '#myPdfList' ).append( '<li> these will be available at <a href="/history.html">the History</a> ( until they are deleted or Sequoia is restarted. )');
			}
			$( "#myPdf" ).show();
			$( "#myPdfList" ).show();
			$( '#myPdfLink1' ).focus();
		}
	);
}

//------------------------------------------------------------
// - used by replace.html to take the list of barcodes entered by the user and add it to the json list
//------------------------------------------------------------
function add_request()
{
	//reset display to blank
	$( '#myList' ).html( my_bc_list );
	//$( "#makeLabels" ).hide();

	// work with the requestLocation
	my_reqestLocation = $( '#requestLocation').val();
	console.log(my_reqestLocation);

	//TODO: refactor this to only take one barcode at a time

	//get the list of barcodes the user entered and clean it up
	var my_bc_list = '';
	my_bc_list = $( '#barcodeInput').val();
	my_bc_list = my_bc_list.replace(/\s+/g, '');  //remove whitespace
	my_bc_list = my_bc_list.replace(/,+/g, ''); //remove commas
	my_bc_list = my_bc_list.toUpperCase(); //because whatever

	//parse the textareinput into a json array
	var array_of_bc = my_bc_list.split(",");

	//check the barcodes against this API to see if they are real:
	// talk to the ItemsInfo.pm service
	var urlbase = '/itemsinfo?barcodes=';
	var url = urlbase + my_bc_list;
	var bc_list_html = '';
	var array_of_good_bc = [];
	var good_bc_list = '';
	var good_bc = '';
	var good_title = '';
	//$.getJSON( url, function( resp )
	var myData ={};
	$.ajax({
		url: url,
		dataType: 'json',
		async: false,
		data: myData,
		success: function (resp)
		{
			//add barcodes to the html list
			for (var i = 0; i < array_of_bc.length; i++) {
				if( array_of_bc[i] != '' ) //avoid adding nulls, this should be redundant
				{
					if (typeof resp[ array_of_bc[i] ] != 'undefined')
					{
						bc_list_html += '<div class="alert alert-success">';
						bc_list_html += '<span class="glyphicon glyphicon-ok"></span> ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; ' + resp[ array_of_bc[i] ].title; // + ' &#8599; ';
						good_bc = array_of_bc[i] ;
						good_title = resp[ array_of_bc[i] ].title;
					}
					else
					{
						bc_list_html += '<div class="alert alert-danger">';
						bc_list_html += '<span class="glyphicon glyphicon-remove"></span> ';
						bc_list_html += array_of_bc[i];
						bc_list_html += ' &mdash; Item not found.';
					}
					bc_list_html += ' </div>';
				}
			}

			//show the result html list
			$( "#myBarcodeList" ).html( bc_list_html );
		}
	});

	if ( good_bc != "" )
	{
		//add the barcodes to the request list on the server:
		// talk to the AddReplacementRequest.pm service
		var urlbase = '/addreplacementrequest?barcodes=';
		var url = urlbase + good_bc;

		myData.barcode = good_bc;
		myData.title = good_title;

		// RV added requester
		myData.reqestLocation = my_reqestLocation
		console.log('add_request() making ajax request...')
		console.log(myData)

		//console.log( "bc:"+myData.barcode );
		//console.log( "title:"+myData.title );
		$.ajax({
			url: url,
			type: 'POST',
			dataType: 'json',
			async: false,
			data: myData,
			success: function (resp)
			{
				//clear rows in place
				$("#myRequestTable").find("tr:gt(0)").remove();

				//sort these results
				var sortable = [];
				for (var r in resp )
				{
					sortable.push([resp[r].request_timestamp, r, resp[r].title]);
				}
				sortable.sort().reverse();//function(a, b) {return a[1] - b[1]});

				for( var s in sortable)
				{
					$("#myRequestTable").find('tbody').append( "<tr>"
							+"<td>"+sortable[s][0]
							+"</td><td>"+sortable[s][1]
							+"</td><td>"+sortable[s][2]
							+"</td><td>"+'<input '
							+'class="checkall" '
							+'type="checkbox" '
							+'name="barcodes_to_archive" '
							+'value="'+sortable[s][1]+'" '+
							'>Archive</input>'
						+"</td></tr>" ) ;
				}
			}
		});
	}//else good_bc was blank
}

//------------------------------------------------------------
// - used by replace.html to load the list of requests on the server and display it
//------------------------------------------------------------
function show_requests()
{
	//reset display to blank
	$( '#myList' ).html( "" );

	//load existing requests from file on server
	var urlbase = './replacementrequests.json';
	var url = urlbase ;
	var rq_list_html = '';
	var barcodes = [];

	$.ajax({
		url: url,
		type: 'GET',
		dataType: 'json',
		cache: false,
		success: function( resp )
		{
			//clear rows in place
			$("#myRequestTable").find("tr:gt(0)").remove();

			//sort these results
			var sortable = [];
			for (var r in resp ) {
				console.log(r);
				// set additional values in the localStorage based on barcode, so we can reference them later
				console.log(JSON.stringify(resp[r]));
				localStorage.setItem(r, JSON.stringify(resp[r]));

				sortable.push([resp[r].request_timestamp, r, resp[r].title]);
				barcodes.push(r);
			}
			sortable.sort().reverse();//function(a, b) {return a[1] - b[1]});

			for( var s in sortable)
			{
				$("#myRequestTable").find('tbody').append( "<tr>"
						+"<td>"+sortable[s][0]
						+"</td><td>"+sortable[s][1]
						+"</td><td>"+sortable[s][2]
						+"</td><td>"+'<input '
							+'class="checkall" '
							+'type="checkbox" '
							+'name="barcodes_to_archive" '
							+'value="'+sortable[s][1]+'" '+
							'>Archive</input>'
						+"</td></tr>" ) ;
			}

			//show the result html list
			//$( "#myRequestList" ).html( rq_list_html );

			console.log('setting barcodes to localStorage in show_requests()')
			localStorage.setItem('barcodes', '[ "' + barcodes.join('", "') + '"] '  );

			console.log(resp);
			
		}
	});

	//load existing requests from file on server
	urlbase = './archivedrequests.json';
	url = urlbase ;
	rq_list_html = '';
	barcodes = [];

	$.ajax({
		url: url,
		type: 'GET',
		dataType: 'json',
		cache: false,
		success: function( resp )
		{
			//clear rows in place
			$("#myArchiveTable").find("tr:gt(0)").remove();

			//sort these results
			var sortable = [];
			for (var r in resp )
			{
				sortable.push([ resp[r].archive_timestamp, resp[r].request_timestamp, r, resp[r].title ]);
				barcodes.push(r);
			}
			sortable.sort().reverse();//function(a, b) {return a[1] - b[1]});

			for( var s in sortable)
			{
				$("#myArchiveTable").find('tbody').append( "<tr>"
						+"<td>"+sortable[s][0]
						+"</td><td>"+sortable[s][1]
						+"</td><td>"+sortable[s][2]
						+"</td><td>"+sortable[s][3]
						+"</td></tr>" ) ;
			}

			//show the result html list
			$( "#myRequestList" ).html( rq_list_html );

			//localStorage.setItem('barcodes', '[ "' + barcodes.join('", "') + '"] '  );
		}
	});
}

function archive_requests()
{
	var checked = [];
	$('input.checkall[type=checkbox]:checked').each( function(){
		checked.push( $(this).val() );
	});
	var barcodes_string = checked.join(',');

	urlbase = './archivereplacementrequests';
	url = urlbase ;
	var myData = {};

	myData.barcodes = barcodes_string;
	myData.password = $('#archivePassword').val();

	$.ajax({
		url: url,
		type: 'GET',
		dataType: 'json',
		cache: false,
		data: myData,
		success: function( resp )
		{
			if (typeof resp.error !== 'undefined'){
				//error ( bad password )
				$('#archivePassword').val( 'password' ).select().focus();
			}
			else{
				show_requests();
			}
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
			//$( "#barcodeInputForm" ).addClass("has-error");
			//$( "#barcodeInputTextArea" ).after( "<br/>input is very long.  be patient." );
		}
		if ( currentString.length < tooLong && re_pattern.test(currentString) )
		{
			$( "#barcodeInputTextArea" ).removeClass("inputBadShadow")
			//$( "#barcodeInputForm" ).removeClass("has-error");
		}

	});

	$('#select-all-checkbox').change(function(e){
		$('.checkall').prop('checked',this.checked);
	});
});
