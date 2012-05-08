#!/usr/bin/perl

# Brian Kintz
# 12.03.2012

# system/gather.pl

# data collection plugin - system information

# collect system information and make it accessible to the main control program

# currently collected:  cpu usage, memory usage, cpu temperature

use strict;
use Switch;
use Fcntl qw(:flock SEEK_END);

require '/root/code/control_auto/config.pl';

my ($fixQual, $lat, $NS, $long, $EW, $satInUse);
my ($satInView, $hdg_mag, $hdg_true);
my (@data, $data_i, $miss);

our $GPS_DATA;

my @fixQualities = ( 'None', 'Standard GPS Fix', 'Differential GPS Fix' );

open(GPS, "</dev/GPS");

$miss = $data_i = 0;

while(1){
   while(<GPS>){
      @data = split(',', $_);
      chomp @data;

      switch ($data[0]) {
         case '$GPGGA' {
            $fixQual = $fixQualities[$data[6]];
            $lat = $data[2] || '-1';
            $NS = $data[3] || '-';
            $long = $data[4] || '-1';
            $EW = $data[5] || '-';
            $satInUse = $data[7] || '0';
         }
            
         case '$GPGSV' { $satInView = $data[3] || '0'; } # there's a bug here
         case '$HCHDG' { $hdg_mag  = $data[1] || '-1'; }
         case '$HCHDT' { $hdg_true = $data[1] || '-1'; }
      }

      if(++$data_i > 3){
         writeData();
         $data_i = 0;
      }
   }

   sleep(1);

   if(++$miss > 4){
      unlink $GPS_DATA;
      $miss = 0;
      sleep(4);
   }
}

sub writeData {
   # open+lock file for writing
   open(FH, ">$GPS_DATA") or die "cannot open > $GPS_DATA";
   flock(FH, LOCK_EX) or die "Cannot lock file $GPS_DATA - $!\n";
   
   print FH "gps_quality|$fixQual\n";
   print FH "gps_lat|$lat\n";
   print FH "gps_long|$long\n";
   print FH "gps_satInUse|$satInUse\n";
   print FH "gps_satInView|$satInView\n";
   print FH "gps_hdg_true|$hdg_true\n";
   print FH "gps_hdg_mag|$hdg_mag\n";

   close FH;
}

