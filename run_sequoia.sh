#!/bin/bash

cd "$(dirname "$0")"

# /usr/bin/cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)

/usr/bin/perl sequoia.pl daemon -m production -l http://127.0.0.1:8080
