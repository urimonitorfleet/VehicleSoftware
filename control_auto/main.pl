#!/usr/bin/perl

use Fcntl qw(:DEFAULT :flock);
use Device::SerialPort;
use Readonly;

require "config.pl";

my %data = ();
my ($key, $val, $temp);
my ($lastDir, $mot_l, $mot_r);

my @area_stack = (-1, -1, -1, -1, -1);

my $mot = Device::SerialPort->new("/dev/ttyUSB0") || die "Can't open /dev/ttyUSB0: $!\n";
   $mot->databits(8);
   $mot->baudrate(9600);
   $mot->parity("none");
   $mot->stopbits(1);

while(1){
   $mot->write(sprintf("%c%c", 0, 0));

   open(FH, "<", $CAM_DATA) or die "cannot open < $CAM_DATA";

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

   $temp = $data{"cent_x"};
   
   if($temp eq "" || $temp == -1){  #not found
      $lastDir = $DIR_NONE;
      $mot_l = $mot_r = $MOT_OFF;
   }elsif($temp < 200){ #left
#   }elsif($temp < 220){
      $mot_l = $MOT_L_R_50;
      $mot_r = $MOT_R_F_50;
      $lastDir = $DIR_LEFT;
   }elsif($temp >= 200 && $temp < 260){ #left transition zone
      if($lastDir == $DIR_LEFT){
         $mot_l = $MOT_L_R_50;
         $mot_r = $MOT_L_R_50;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }
   }elsif($temp >= 260 && $temp <= 380){ #center
#   }elsif($temp >= 220 && $temp <= 420){ 
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }elsif($temp > 380 && $temp <= 440){ #right transition zone
      if($lastDir == $DIR_RIGHT){
         $mot_l = $MOT_L_F_50;
         $mot_r = $MOT_R_R_50;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }
   }elsif($temp > 440){ #right
#   }elsif($temp > 420){
      $mot_l = $MOT_L_F_50;
      $mot_r = $MOT_R_R_50;
      $lastDir = $DIR_RIGHT;
   }else{
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }

   $temp = $data{"area"};
   pop(@area_stack);
   unshift(@area_stack, $area);
   
   $temp = avg(\@area_stack);
   
   if($temp > 0 && $lastDir == $DIR_STOP){
      if($temp < 1000){
         $mot_l = $MOT_L_R_50;
         $mot_r = $MOT_R_R_50;
      }elsif($temp > 10000){
         $mot_l = $MOT_L_F_50;
         $mot_r = $MOT_R_F_50;
      }
   }

   $mot->write(sprintf("%c%c", $mot_l, $mot_r));
   
   writeXML(%data);
   select(undef, undef, undef, 0.05);
}

exit;

sub avg {
   my ($in) = @_;
   my $total;
   my $count = scalar @$in;

   foreach (@$in) { 
      if($_ == -1) { return -1; }

      $total += $_; 
   }

   return $total / $count;
}

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

