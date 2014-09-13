# tmc-misc-scripts #

General policy: all scripts must understand `-h` and `--help`.

## `irc_log_htmlizer.rb` ##

Transforms [eggdrop](http://www.eggheads.org/) IRC log files to HTML.

## `create_remote_user.sh` ##

Creates a user account on a remote host, and copies over their local
`.ssh/authorized_keys`, if it exists, or generates a random password if not.

## `include/firewall-utils.bash` ##

Helper functions to include in `/etc/rc.local` or similar to set up
simple port forwarding with iptables.
