#!/usr/bin/perl

# Brian Kintz
# 12.03.2012

# system/gather.pl

# data collection plugin - system information

# collect system information and make it accessible to the main control program

# currently collected:  cpu usage, memory usage, cpu temperature
# interval:  2 seconds

use strict;
use Fcntl qw(:flock SEEK_END);

require '/root/code/control_auto/config.pl';

my ($hostname, $ip_eth, $ip_wlan, @cpu_usage, $mem_usage, $cpuTemp);
our $SYS_DATA;

while(1){
   # get hostname
   $hostname = `cat /etc/hostname`;

   # get IP addresses
   ($ip_eth, $ip_wlan) = `ifconfig | grep "inet " | awk 'NR!=2{split(\$2,a,":"); print a[2]}'`;
   
   # get cpu usage (== 100% - idle %)
   @cpu_usage = `sar -P ALL 1 1 | awk 'NR==5,NR==6 {print 100-\$8}'`;

   # get current memory usage
   $mem_usage = `sar -r 1 1 | awk 'NR==4 {print \$4; exit}'`;

   # get current cpu temp in deg C
   $cpuTemp = `sensors -A | grep temp1 | awk 'NR==2 {print \$2; exit}'`;
   $cpuTemp =~ s/^.//;

   chomp ($hostname, $ip_eth, $ip_wlan, @cpu_usage, $mem_usage, $cpuTemp);

   # open+lock file for writing
   open(FH, ">$SYS_DATA") or die "cannot open > $SYS_DATA";
   flock(FH, LOCK_EX) or die "Cannot lock file $SYS_DATA - $!\n";

   # write data
   print FH "com_hostname|$hostname\n";
   print FH "com_ipAddr_eth|$ip_eth\n";
   print FH "com_ipAddr_wlan|$ip_wlan\n";
   print FH 'os_usage_cpu|Core0:  ' . $cpu_usage[0] . '%,  Core1:  ' . $cpu_usage[1] . "%\n";
   print FH "os_usage_mem|$mem_usage%\n";
   print FH "os_temp_cpu|$cpuTemp" . "C\n";

   # clean up
   close FH;

   sleep(2);
}

