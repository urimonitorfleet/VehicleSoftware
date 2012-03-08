#!/usr/bin/perl

use FTDI::D2XX;

#my $FTDI = FTDI::D2XX->new(1);

#print $FTDI->GetNumDevices();

my $handle;
FT_Open($handle, 0);



FTDI::D2XX::FT_Close($handle);
#$data = 'a';

#$FTDI->FT_Write($data);
