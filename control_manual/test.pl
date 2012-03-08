#!/usr/bin/perl

use Device::SerialPort;

my $serial_conf_file = "ttyUSB_perl_conf";

my $mc = Device::SerialPort->new("/dev/ttyUSB0")
   || die "Can't open /dev/ttyUSB0: $!\n";
   $mc->databits(8);
   $mc->baudrate(9600);
   $mc->parity("none");
   $mc->stopbits(1);
#   $mc->write_settings || undef $mc;

#sleep(2);

$i = 0;
while($i++ < 5){
   $mc->write(sprintf("%c", 127));
   sleep(1);
}

$mc->write(sprintf("%c", 0));

exit;
