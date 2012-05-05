# Brian Kintz
# 2.11.2012

# audoControl.sh - utility script to start/stop autonomous control

#!/bin/bash

if [ $# -lt 1 ]
then
   echo "Usage : $0 [start|stop|restart]"
   exit
fi

PLUGIN_DIR=/root/code/control_auto/plugins
SCRIPT_DIR=/root/code/scripts
MJPG_DIR=/root/scripts/mjpg_dir
CONTROL_DIR=/root/code/control_auto

case "$1" in

start) echo "Starting autonomous control..."
       echo -n "\tSetting up temp directories..."
       if [ ! -d "/tmp/data" ]; then
         mkdir /tmp/data
         echo "Done."
       else
         echo "Not necessary."
       fi
     
       echo "\tStarting data collection plugins..."
       echo -n "\t --System Information..."
       $PLUGIN_DIR/system/gather.pl&
       if [ -z "$(ps -aef | grep system/gather.pl | grep -v grep)" ]; then
         echo "Failed!!\n"
         $0 stop
         exit
       else
         echo "Done."
       fi

       echo -n "\t --GPS..."
       if [ -e "/dev/GPS" ]; then
         $PLUGIN_DIR/gps/gather.pl&
         if [ -z "$(ps -aef | grep gps/gather.pl | grep -v grep)" ]; then
            echo "Failed!!\n"
            $0 stop
            exit
         else
            echo "Done."
         fi
       else
         echo "No GPS Connected!!"
       fi

       #start video streaming
       $SCRIPT_DIR/stream.sh mjpg_file
      
       echo -n "\tStarting control loop..."
       $CONTROL_DIR/main.pl&
       
       sleep 1

       if [ -z "$(ps -aef | grep main.pl | grep -v grep)" ]; then
         echo "Failed!!\n"
         $0 stop
         exit
       else
         echo "Done."
       fi

       echo "Started."
       ;;

stop)  echo "Stopping autonomous control..."
       echo "\tStopping video stream..."
       $SCRIPT_DIR/stream.sh stop

       echo -n "\tStopping data collection plugins..."
       PID=$(ps -aef | grep gather | grep -v grep | awk '{print $2}')
       if [ -n "$PID" ]; then
         kill -9 $PID
         echo "Done."
       else
         echo "Not necessary."
       fi

       echo -n "\tStopping control loop..."
       PID=$(ps -aef | grep main.pl | grep -v grep | awk '{print $2}')
       if [ -n "$PID" ]; then
         kill -9 $PID
         echo "Done."
       else
         echo "Not necessary."
       fi

       echo -n "\tCleaning up files..."
       rm -rf /tmp/data
       rm /tmp/www/data.xml
       echo "Done."

       echo "Stopped."
       ;;

restart) $0 stop
         $0 start
         ;;

*)     echo "Invalid option"
       ;;
esac
