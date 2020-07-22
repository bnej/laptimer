#!/usr/bin/bash
cd /opt/laptimer
plackup -E production -s Starman --workers=2 -l /opt/laptimer/var/laptimer.sock -a bin/app.pl
