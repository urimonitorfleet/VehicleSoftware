#!/usr/bin/perl

# Brian Kintz
# 12.03.2012

# main.pl

# main autonomous control program

# reads information from the generated files in /tmp/data and uses

# it to make a movement decision, which it relays to the motor controller

# loop interval: 1/10 second
use Fcntl qw(:DEFAULT :flock);
use Device::SerialPort;
use Math::Trig;
use LWP::Simple;

require "/root/code/control_auto/config.pl";

my ($temp);
my ($lastDir, $mot_l, $mot_r);

my @area_stack = (-1) x 10;

my $mot = Device::SerialPort->new("/dev/MotorController") || die "Can't open /dev/MotorController: $!\n";
   $mot->databits(8);
   $mot->baudrate(9600);
   $mot->parity("none");
   $mot->stopbits(1);

my $op_mode = $OP_MODE_DRONE_LEFT;

while(1){
   $mot->write(sprintf("%c%c", 0, 0));

   my $data = getData();

   if($op_mode == $OP_MODE_FLAGSHIP){
      driveVideo($data);
      #writeDroneCommands($data);
   }elsif($op_mode & ($OP_MODE_DRONE_RIGHT | $OP_MODE_DRONE_LEFT)){
      driveGPS($data);
   }

   writeXML($data);
   select(undef, undef, undef, 0.5);
}

######################################################################
# subs
######################################################################
sub driveVideo {
   my $data = shift;
   
   $temp = $data->{"cent_x"};

   if($temp eq "" || $temp == -1){  #not found
      $lastDir = $DIR_NONE;
      $mot_l = $mot_r = $MOT_OFF;
   }elsif($temp < 200){ #left
      $mot_l = $MOT_L_F_75;
      $mot_r = $MOT_R_R_75;
      $lastDir = $DIR_RIGHT;
   }elsif($temp >= 200 && $temp < 260){ #left transition zone
      if($lastDir == $DIR_RIGHT){
         $mot_l = $MOT_L_F_75;
         $mot_r = $MOT_R_R_75;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }
   }elsif($temp >= 260 && $temp <= 380){ #center
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }elsif($temp > 380 && $temp <= 440){ #right transition zone
      if($lastDir == $DIR_LEFT){
         $mot_l = $MOT_L_R_75;
         $mot_r = $MOT_R_F_75;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }
   }elsif($temp > 440){ #right
      $mot_l = $MOT_L_R_75;
      $mot_r = $MOT_R_F_75;
      $lastDir = $DIR_LEFT;
   }else{
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }

   $temp = $data->{"area"};

   pop(@area_stack);
   unshift(@area_stack, $temp);

   $temp = avg(\@area_stack);

   if($temp > 0 && $lastDir != $DIR_LEFT && $lastDir != $DIR_RIGHT){
      if($temp < 300){
         $mot_l = $MOT_L_F_75;
         $mot_r = $MOT_R_F_75;
         $lastDir = $DIR_FORWARD;
      }elsif($temp >= 300 && $temp < 400){
         if($lastDir == $DIR_FORWARD){
            $mot_l = $MOT_L_F_75;
            $mot_r = $MOT_R_F_75;
         }else{
            $mot_l = $mot_r = $MOT_OFF;
            $lastDir = $DIR_STOP;
         }
      }elsif($temp >= 400 && $temp < 1000){
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }elsif($temp >= 1000 && $temp < 1500){
         if($lastDir == $DIR_REVERSE){
            $mot_l = $MOT_L_R_75;
            $mot_r = $MOT_R_R_75;
         }else{
            $mot_l = $mot_r = $MOT_OFF;
            $lastDir = $DIR_STOP;
         }
      }elsif($temp > 1500){
         $mot_l = $MOT_L_R_75;
         $mot_r = $MOT_R_R_75;
         $lastDir = $DIR_REVERSE;
      }
   }

   $mot->write(sprintf("%c%c", $mot_l, $mot_r));
}

sub BearingTo {
   my $dLat = shift;
   my $dLong = shift;

   if($dLong == 0){
      return 180 * ($dLat < 0);
   }

   my $t = atan($dLat/$dLong);
   print $t;

   $t = $t * 180 / pi;
   print ",  $t,  ";

   $t = ($dLong > 0 ? -90 : 90) - $t;
   print $t;
   
   $t = ( $t < 0) ? 360 + $t : $t;
   print ", $t";
   return $t;
}

sub driveGPS {
   my $data = shift;
   my %gps = ();
print "\n";
   if(!exists $data->{ 'gps_lat' } || !exists $data->{ 'gps_long' } ||
      $data->{ 'gps_lat' } == -1 || $data->{ 'gps_long' } == -1){
     print "no data"; 
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;

      $mot->write(sprintf("%c%c", $mot_l, $mot_r));
      return;
   }

   my @flagship = split(/\n/, get('http://192.168.1.4/commands'));

   foreach (@flagship) {
      my($key, $val) = split(/:/);

      $gps{ $key } = $val;
   }
 
   my $tgtKey = $OP_MODE_DRONE_LEFT ? 'left_dest' : 'right_dest';

   if(!exists $gps{ $tgtKey } || $gps{ $tgtKey } < 0){
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }else{
      my $lat = $data->{ 'gps_lat' };
      my $long = $data->{ 'gps_long' };

      my ($tgtLat, $tgtLong) = split(/,/, $gps{ $tgtKey });

      my $delLat = $tgtLat - $lat;
      my $delLong = $tgtLong  - $long;

      print "dLat: $delLat, dLong: $delLong, ";

      if($delLat < .003 && $delLat > -.003 && $delLong < .003 && $delLong > -.003){
          $mot_l = $mot_r = $MOT_OFF;
          $lastDir = $DIR_STOP;
          print "in box\n";
      }else{
         my $bt = BearingTo($delLat, $delLong);
         my $hdg = $data->{ "gps_hdg_true" };

         my $delHdg = $hdg - $bt;

         if($delHdg < -180 || $delHdg > 180){
            $delHdg = $bt - $hdg;
         }

         print ", $delHdg";
         $mot_l = 120;
         $mot_r = 248;

         if($delHdg < -90){
            $mot_l = $MOT_L_R_75;
            $lastDir = $DIR_RIGHT;
         }elsif($delHdg < -5){
            $mot_l = $MOT_L_STOP; #$delHdg / 10;
            $lastDir = $DIR_RIGHT;
         }elsif($delHdg > 90){
            $mot_r = $MOT_R_R_75;
            $lastDir = $DIR_LEFT;
         }elsif($delHdg > 5){
            $mot_r = $MOT_R_STOP; #$delHdg / -10;
            $lastDir = $DIR_LEFT;
         }
      }
      $mot->write(sprintf("%c%c", $mot_l, $mot_r));
   }
}

sub getData {
   my %data = ();
   my ($key, $value);

   my @files = glob("/tmp/data/*");

   foreach (@files) {
      open(FH, "<$_") or die "Cannot open file < $_ - $!";
      flock(FH, LOCK_EX) or die "Cannot lock file $_ - $!\n";

      while(<FH>){
         chomp;
         ($key, $val) = split(/\|/);
         $data{ $key } = $val;
      }

      close FH;
   }

   return \%data;
}

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
   my $data = shift;
   
   my $out = $openDataRoot;
   my $temp;

   foreach $key (sort keys %$data) {
      $out .= $openObj;
      $out .= $openMN . $key . $closeMN;

      if (!($temp = $displayNames{ $key })) {
         $temp = "Undefined";
      }

      $out .= $openDN . $temp . $closeDN;
      $out .= $openVal . $data->{ $key } . $closeVal;

      $out .= $closeObj;
   }

   $out .= $closeDataRoot;

   open(FILE, ">$WWW_DATA");

   print FILE $out;

   close(FILE);
}

sub writeDroneCommands {
   my $data = shift;
   my $lat, $long, $out;

   if(!exists $data{ $gps_lat } || !exists $data{ $gps_long }){
      $out = "left_dest:-1,-1\nright_dest:-1,-1";
   }else{
      $lat = $data{ $gps_lat };
      $long = $data{ $gps_long };

      if($lat > 0 && $long > 0){
         #figure out where to send the drones
      }else{
         $out = "left_dest:-1,-1\nright_dest:-1,-1";
      }
   }

   open(FILE, ">$WWW_DRONE_CMDS");

   print FILE $out;

   close(FILE);
}
