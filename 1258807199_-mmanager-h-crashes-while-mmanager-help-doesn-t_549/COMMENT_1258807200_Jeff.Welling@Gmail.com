
For some reason, as of commit e0c6d3ab1a8a1085587ae8d53c892dacf50e94d6, running `./bin/mmanager -h` produces an error but using 'help' instead works just fine.  The fuck?
