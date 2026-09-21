#!/bin/sh
set -eu
iptables -L INPUT -n -v --line-numbers
echo
iptables -L FORWARD -n -v --line-numbers
