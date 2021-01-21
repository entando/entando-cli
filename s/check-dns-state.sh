#!/bin/bash

dig -v 2>/dev/null 1>&2
[ $? -ne 0 ] && echo "Please install dig" 2>&1

B0=$(dig +short 192.168.1.1.nip.io | tail -n1 | wc -l)
B1=$(dig +short google.com @8.8.8.8 | tail -n1 | wc -l)
B2=$(dig +short 192.168.1.1.nip.io @8.8.8.8 | tail -n1 | wc -l)
B3=$(dig +short google.com @8.8.8.8 | tail -n1 | wc -l)

P="$B0$B1$B2$B3"

case $P in
0000) echo "no-dns" ;;
0011) echo "no-loc-dns" ;;
0111) echo "filtered[R]" ;;
0?0?) echo "filtered[RR]" ;;
1111) echo "full" ;;
*) echo "weird[$P]" ;;
esac
