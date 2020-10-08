* where does the javascript function: add_request() _actually_ add the request?
    * the comments say: add the barcodes to the request list on the server ...
    this means the "replacementrequests.json" in the ./public folder in the sequia app... 
    BUT ... the barcodes _appear_ to be pulled only from the browsers localStorage when the button, "Make PDF of these Requests" button is pressed. WHY?!?

    sequoia.pl -> addreplacementrequest

    ```perl
    # stash the barcodes to somewhere
	Sequoia::ReplacementRequests::add_request_to_request_list( $barcode, $title, $reqestLocation );
    ```

    Sequoia::ReplacementRequests::add_request_to_request_list
    writes to 
    
    ```perl
    my $filename = 'replacementrequests.json';
    ```





    * perl function: add_request_to_request_list 


    show_request reads the JSON file from the local server's public page




<!-- in the javascript , instead of passing a list of barcodes  -->
window.localStorage.setItem('user', JSON.stringify(person));