# Brian Kintz
# 2.11.2012

# audoControl.sh - utility script to start/stop autonomous control

#!/bin/bash

if [ $# -lt 1 ]
then
   echo "Usage : $0 [start|stop]"
   exit
fi

SCRIPT_DIR=/root/code/scripts
MJPG_DIR=/root/scripts/mjpg_dir
CONTROL_DIR=/root/code/control_auto

case "$1" in

start) echo "Starting autonomous control..."
       echo -n "--Setting up temp directories..."
       if [ ! -d "/tmp/control" ]; then
         mkdir /tmp/control
         touch /tmp/control/clVidFrame
         #echo "cent_x:-1" > /tmp/control/clVidFrame
         echo "Done."
       else
         echo "Not necessary."
       fi
 
       #start video streaming
       $SCRIPT_DIR/stream.sh mjpg_file

       echo -n "--Starting control loop..."
       $CONTROL_DIR/main.pl&
       
       sleep 1

       if [ -z "$(ps -aef | grep main.pl | grep -v grep | awk '{print $2}')" ]; then
         echo "Failed!!"
         $0 stop
         exit
       else
         echo "Done."
       fi

       echo "Started."
       ;;

stop)  echo "Stopping autonomous control..."
       echo -n "--Stopping video stream..."
       PID=$(pidof mjpg_streamer)
       if [ -n "$PID" ]; then
         kill -9 $PID
         echo "Done."
       else
         echo "Not necessary."
       fi

       echo -n "--Stopping control loop..."
       PID=$(ps -aef | grep main.pl | grep -v grep | awk '{print $2}')
       if [ -n "$PID" ]; then
         kill -9 $PID
         echo "Done."
       else
         echo "Not necessary."
       fi

       echo -n "--Cleaning up files..."
       rm -rf /tmp/control
       echo "Done."

       echo "Stopped."
       ;;

*)     echo "Invalid option"
       ;;
esac
