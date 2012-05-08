#!/usr/bin/perl

# Brian Kintz
# 5.8.2012

# main.pl

# main autonomous control program

# reads information from the generated files in /tmp/data and uses
# it to make a movement decision, which it relays to the motor controller

# imports
use Fcntl qw(:DEFAULT :flock);
use Device::SerialPort;
use Math::Trig;
use LWP::Simple;

# import configuration data
require "/root/code/control_auto/config.pl";

# globals
my ($lastDir, $mot_l, $mot_r);
my @area_stack = (-1) x 10;

# open connection to motor controller
my $mot = Device::SerialPort->new("/dev/MotorController") || die "Can't open /dev/MotorController: $!\n";
   $mot->databits(8);
   $mot->baudrate(9600);
   $mot->parity("none");
   $mot->stopbits(1);

# define operating mode
#my $op_mode = $OP_MODE_FLAGSHIP;
my $op_mode = $OP_MODE_DRONE_LEFT;
#my $op_mode = $OP_MODE_DRONE_RIGHT;

# main control loop
while(1){
   $mot->write(sprintf("%c%c", 0, 0));

   my $data = getData();

   if($op_mode == $OP_MODE_FLAGSHIP){
      driveVideo($data);
      writeDroneCommands($data);
   }elsif($op_mode & ($OP_MODE_DRONE_RIGHT | $OP_MODE_DRONE_LEFT)){
      driveGPS($data);
   }

   writeXML($data);

   # wait
   select(undef, undef, undef, 0.5);
}

# Camera drive mode
sub driveVideo {
   my $data = shift;
   my $temp = $data->{'cent_x'} || -1;

   # turn left or right based on where the object centroid is
   if($temp < 0){  #not found
      $lastDir = $DIR_NONE;
      $mot_l = $mot_r = $MOT_OFF;

   # left
   }elsif($temp < 200){
      $mot_l = $MOT_L_F_75;
      $mot_r = $MOT_R_R_75;
      $lastDir = $DIR_RIGHT;

   # left transition zone
   }elsif($temp >= 200 && $temp < 260){
      if($lastDir == $DIR_RIGHT){
         $mot_l = $MOT_L_F_75;
         $mot_r = $MOT_R_R_75;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }

   # center
   }elsif($temp >= 260 && $temp <= 380){ 
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;

   # right transition zone
   }elsif($temp > 380 && $temp <= 440){
      if($lastDir == $DIR_LEFT){
         $mot_l = $MOT_L_R_75;
         $mot_r = $MOT_R_F_75;
      }else{
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;
      }

   # right
   }elsif($temp > 440){
      $mot_l = $MOT_L_R_75;
      $mot_r = $MOT_R_F_75;
      $lastDir = $DIR_LEFT;

   # catch-all
   }else{
      $mot_l = $mot_r = $MOT_OFF;
      $lastDir = $DIR_STOP;
   }

   $temp = $data->{"area"} || -1;

   # add current to area stack and calculate average of the last 10 areas
   pop(@area_stack);
   unshift(@area_stack, $temp);
   $temp = avg(\@area_stack);

   # only drive forwards/backwards if we have a useable area AND we're not turning
   if($temp > 0 && $lastDir != $DIR_LEFT && $lastDir != $DIR_RIGHT){
      
      # if it's too small, drive forwards
      if($temp < 300){
         $mot_l = $MOT_L_F_75;
         $mot_r = $MOT_R_F_75;
         $lastDir = $DIR_FORWARD;

      # forward transition zone
      }elsif($temp >= 300 && $temp < 400){
         if($lastDir == $DIR_FORWARD){
            $mot_l = $MOT_L_F_75;
            $mot_r = $MOT_R_F_75;
         }else{
            $mot_l = $mot_r = $MOT_OFF;
            $lastDir = $DIR_STOP;
         }

      # juuuuuuuuuust right  :)
      }elsif($temp >= 400 && $temp < 1000){
         $mot_l = $mot_r = $MOT_OFF;
         $lastDir = $DIR_STOP;

      # backwards transition zone
      }elsif($temp >= 1000 && $temp < 1500){
         if($lastDir == $DIR_REVERSE){
            $mot_l = $MOT_L_R_75;
            $mot_r = $MOT_R_R_75;
         }else{
            $mot_l = $mot_r = $MOT_OFF;
            $lastDir = $DIR_STOP;
         }

      # if it's too big then back up
      }elsif($temp > 1500){
         $mot_l = $MOT_L_R_75;
         $mot_r = $MOT_R_R_75;
         $lastDir = $DIR_REVERSE;
      }
   }

   # go go go!
   $mot->write(sprintf("%c%c", $mot_l, $mot_r));
}

# calculate the relative bearing to a point based on the latitude + longitude change
sub BearingTo {
   my $dLat = shift;
   my $dLong = shift;

   # if it's straight in front of or behind us
   if($dLong == 0){
      return 180 * ($dLat < 0);
   }

   # get the bearing in radians
   my $t = atan($dLat/$dLong);

   # bearing -> degrees
   $t = $t * 180 / pi;

   # adjust output to be +- 180 degrees
   $t = ($dLong > 0 ? -90 : 90) - $t;
   
   return ( $t < 0) ? 360 + $t : $t;
}

# GPS drive mode
sub driveGPS {
   my $data = shift;
   my %gps = ();

   # get the current and destination GPS coordinates
   my $lat = $data->{ 'gps_lat' } || -1;
   my $long = $data->{ 'gps_long' } || -1;

   # make sure we have a useable GPS fix, otherwise don't go anywhere
   if($lat < 0 || $long < 0){
      $lastDir = $DIR_STOP;
      $mot->write(sprintf("%c%c", $MOT_OFF, $MOT_OFF));
      return;
   }

   # get the destination from the flagship (currently fixed to seagull 1)
   my @flagship = split(/\n/, get('http://192.168.1.4/commands'));

   # break apart the destination into a hash
   foreach (@flagship) {
      my($key, $val) = split(/:/);

      $gps{ $key } = $val;
   }
 
   # find the destination for our vehicle in the hash
   my $tgtKey = $OP_MODE_DRONE_LEFT ? 'left_dest' : 'right_dest';

   # if we can't find it, stop and quit
   if(!exists $gps{ $tgtKey } || $gps{ $tgtKey } < 0){
      $lastDir = $DIR_STOP;
      $mot->write(sprintf("%c%c", $MOT_OFF, $MOT_OFF));
      return;
   }

   # extract the destination
   my ($tgtLat, $tgtLong) = split(/,/, $gps{ $tgtKey });

   # calculate the lat/long changes
   my $delLat = $tgtLat - $lat;
   my $delLong = $tgtLong  - $long;

#print "dLat: $delLat, dLong: $delLong, ";

   # are we already there?  if so, stay there
   if($delLat < .001 && $delLat > -.001 && $delLong < .001 && $delLong > -.001){
       $mot_l = $mot_r = $MOT_OFF;
       $lastDir = $DIR_STOP;

#print "in box\n";
   }else{
      # calculate the bearing to the destination
      my $bt = BearingTo($delLat, $delLong);
      my $hdg = $data->{ "gps_hdg_true" };

      # figure out the heading change to that bearing
      my $delHdg = $hdg - $bt;

      if($delHdg < -180 || $delHdg > 180){
         $delHdg = $bt - $hdg;
      }

#print ", $delHdg\n";

      $mot_l = $MOT_L_F_75;
      $mot_r = $MOT_R_F_75;

      # set the motor speeds to turn and drive towards the destination
      if($delHdg < -90){
         $mot_l = $MOT_L_R_75;
         $lastDir = $DIR_LEFT;
      }elsif($delHdg < -5){
         $mot_l = $MOT_L_STOP;
         $lastDir = $DIR_LEFT;
      }elsif($delHdg > 90){
         $mot_r = $MOT_R_R_75;
         $lastDir = $DIR_RIGHT;
      }elsif($delHdg > 5){
         $mot_r = $MOT_R_STOP;
         $lastDir = $DIR_RIGHT;
      }
   }

   $mot->write(sprintf("%c%c", $mot_l, $mot_r));
}

# read all the available data from plugins in /tmp/data/
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

# export all the data to an XML file for the tablet
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

# calculate where each drone should be and write it to a file
sub writeDroneCommands {
   my $data = shift;
   my $out;
   
   # polar-coordinate distance to the desired drone location
   my $R = 0.0035;

   my $lat = $data->{ 'gps_lat' } || -1;
   my $long = $data->{ 'gps_long' } || -1;
   my $hdg = $data->{ 'gps_hdg_true' } || -1;

   if($lat < 0 || $long < 0 || $hdg < 0){
      $out = "left_dest:-1,-1\nright_dest:-1,-1";
   }else{
      # calculate angle of left drone (45deg from flagship heading)
      $theta = ($hdg > 180) ? $hdg - 225 : $hdg - 45;

      # calculate opposite/adjacent legs of left triangle
      # no need to calculate the right because all the angles add up to 180
      # this makes the magnitudes of the side lenghts for the right drone 
      # exactly the opposite.  then we just need to play with the sign to get it right
      $adj = sprintf("%.5f", abs($R * cos($theta)));
      $opp = sprintf("%.5f", abs($R * sin($theta)));

      # tweak the signs depending on the angle of the left drone
      if($hdg < 45 || ($hdg > 180 && $hdg - 180 < 45)){
         $dLatL = $adj;
         $dLatR = $opp;

         $dLongL = $opp;
         $dLongR = $adj * -1;
      }elsif($hdg < 135 || ($hdg > 180 && $hdg  - 180 < 135)){
         $dLatL = $adj;
         $dLatR = $opp * -1;

         $dLongL = $opp * -1;
         $dLongR = $adj * -1;
      }else{
         $dLatL = $adj * -1;
         $dLatR = $opp * -1;

         $dLongL = $opp * -1;
         $dLongR = $adj;
      }

      # if the flagship heading is > 180deg, everything is backwards.  yay trig!
      if($hdg > 180){
         $dLatL *= -1;
         $dLatR *= -1;

         $dLongL *= -1;
         $dLongR *= -1;
      }

      # calculate the final destination and assemble the output line
      $lLat = $lat + $dLatL;
      $rLat = $lat + $dLatR;

      $lLong = $long + $dLongL;
      $rLong = $long + $dLongR;
   
      $out = "left_dest:$lLat,$lLong\nright_dest:$rLat,$rLong";
   }

   # write to command file
   open(FILE, ">$WWW_DRONE_COMMANDS");

   print FILE $out;

   close(FILE);
}
