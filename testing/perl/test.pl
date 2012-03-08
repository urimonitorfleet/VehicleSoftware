#!/usr/bin/perl

use Fcntl qw(:DEFAULT :flock);

require "/root/code/control_auto/config.pl";

my %data = ();
my ($key, $val, $temp);

open(FH, "<$CAM_DATA") or die "cannot open < $CAM_DATA";

unless (flock(FH, LOCK_SH | LOCK_NB)){
select(undef, undef, undef, 0.02);
   flock(FH, LOCK_SH) or die "Couldn't lock file $CAM_DATA";
}

while(<FH>){
   chomp;
   ($key, $val) = split(/:/);
   $data{ $key } = $val;
}

close FH;

writeXML(%data);


##########################################################

sub writeXML {
   my (%data) = @_;

   my $out = $openDataRoot;
   my $temp;

   while (my ($key, $value) = each(%data)) {
      $out .= $openObj;
      $out .= $openMN . $key . $closeMN;

      if (!($temp = $data { $key })) {
         $temp = "Undefined";
      }

      $out .= $openDN . $temp . $closeDN;
      $out .= $openVal . $value . $closeVal;

      $out .= $closeObj;
   }

   $out .= $closeDataRoot;

   open(FILE, ">$WWW_DATA");

   print FILE $out;

   close(FILE);
}
