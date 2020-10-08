#!/bin/bash
# this script will run sequoia for production
# If for testing, then run this command (with the port wanted for testing):
# sudo morbo -l http://0.0.0.0:3000 sequoia.pl

cd /home/plchuser/app/sequoia/
/home/plchuser/app/sequoia/sequoia.pl daemon -m production -l http://127.0.0.1:8080
