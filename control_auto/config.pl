#!/usr/bin/perl

# Brian Kintz
# 3.06.2012

# config.pl - configuration and static variable definitions

use strict;
use Readonly;

# Operating Mode Definitions
Readonly our $OP_MODE_FLAGSHIP => 1;
Readonly our $OP_MODE_DRONE_LEFT => 2;
Readonly our $OP_MODE_DRONE_RIGHT => 4;

# Motor Speed Definitions
Readonly our $MOT_L_R_100 => 1;
Readonly our $MOT_L_R_75 => 16;
Readonly our $MOT_L_R_50 => 32;
Readonly our $MOT_L_R_25 => 48;
Readonly our $MOT_L_STOP => 64;
Readonly our $MOT_L_F_25 => 80;
Readonly our $MOT_L_F_50 => 96;
Readonly our $MOT_L_F_75 => 112;
Readonly our $MOT_L_F_100 => 127;

Readonly our $MOT_R_R_100 => 129;
Readonly our $MOT_R_R_75 => 144;
Readonly our $MOT_R_R_50 => 160;
Readonly our $MOT_R_R_25 => 176;
Readonly our $MOT_R_STOP => 192;
Readonly our $MOT_R_F_25 => 208;
Readonly our $MOT_R_F_50 => 224;
Readonly our $MOT_R_F_75 => 240;
Readonly our $MOT_R_F_100 => 255;

Readonly our $MOT_OFF => 0;
Readonly our $MOT_25_PCT => 16;
Readonly our $MOT_50_PCT => 32;

# Directional Bindings
Readonly our $DIR_NONE => -1;
Readonly our $DIR_STOP => 1;
Readonly our $DIR_RIGHT => 2;
Readonly our $DIR_LEFT => 4;
Readonly our $DIR_FORWARD => 8;
Readonly our $DIR_REVERSE => 16;

Readonly our %displayNames => (
   "op_mode" => "Operating Mode",
   "op_pos" => "Operating Position",
   "com_hostname" => "Vehicle OS Hostname",
   "com_ipAddr_wlan" => "IP Address - Wireless",
   "com_ipAddr_eth" => "IP Address - Wired Ethernet",
   "gps_quality" => "GPS Fix Quality",
   "gps_lat" => "Latitude",
   "gps_long" => "Longitude",
   "gps_satInUse" => "Satellites In Use",
   "gps_satInView" => "Satellites In View",
   "gps_hdg_true" => "Heading (True)",
   "gps_hdg_mag" => "Heading (Magnetic)",
   "cent_y" => "Target Centroid - Y (pixels)",
   "cent_x" => "Target Centroid - X (pixels)",
   "area" => "Target Area (pixels)",
   "os_usage_cpu" => "CPU Usage",
   "os_usage_mem" => "Memory Usage",
   "os_temp_cpu" => "CPU Temperature"
);

Readonly our $openDataRoot => "<Data>\n";
Readonly our $closeDataRoot => "</Data>";
Readonly our $openObj => "\t<DataItem>\n";
Readonly our $closeObj => "\t</DataItem>\n";
Readonly our $openMN => "\t\t<machineName>";
Readonly our $closeMN => "</machineName>\n";
Readonly our $openDN => "\t\t<displayName>";
Readonly our $closeDN => "</displayName>\n";
Readonly our $openVal => "\t\t<value>";
Readonly our $closeVal => "</value>\n";

# Data Directories
Readonly our $WWW_DATA => "/tmp/www/data.xml";
Readonly our $WWW_DRONE_COMMANDS => "/tmp/www/commands";
Readonly our $CAM_DATA => "/tmp/data/video";
Readonly our $SYS_DATA => "/tmp/data/system";
Readonly our $GPS_DATA => "/tmp/data/gps";
















