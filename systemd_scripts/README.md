# Autmatically Starting the Sequoia Service 

This can be done via systemd script.

Install the script at the following path:

`/etc/systemd/system/sequoia.service`

note: after copying the script, you may need to run the following command:

`sudo systemctl daemon-reload`

Issuing the following commands will start / stop / restart the service:

* start: `sudo systemctl start sequoia.service`
* stop: `sudo systemctl stop sequoia.service`
* restart: `sudo systemctl restart sequoia.service`
