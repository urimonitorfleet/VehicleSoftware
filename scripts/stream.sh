# Brian Kintz
# 3.04.2012

# stream.sh - utility script to start/stop live video streaming
#
# Returns:  Success = 0, Fail = -1

#!/bin/bash

init_mjpg () {
   rmmod uvcvideo
   modprobe uvcvideo

   export LD_LIBRARY_PATH=$MJPG_DIR
}

check_pid () {
   if [ -z "$1" ] || [ -z "$(pidof $1)" ]; then
      echo "Failed!!\n"
      $0 stop
      exit 1
   else
      echo "Done."
   fi
}

stop_pid () {
   if [ -z "$1" ]; then
      echo -n "\nNothing to kill; Exiting."
      exit 0
   fi

   PID=$(pidof $1)
   
   echo -n "\t --Killing $1..."

   if [ -n "$PID" ]; then
      kill -9 $PID
      echo "Done."
   else
      echo "Not necessary."
   fi
}

if [ $# -lt 1 ]
then
   echo "Usage : $0 {mjpg|mjpg_file|vlc|vlc_file|stop}"
   exit 1
fi

MJPG_DIR=/usr/share/mjpg-streamer
CONTROL_DIR=/root/code/control_auto

WLAN_IP=$(ifconfig wlan0 | grep "inet " | awk 'NR!=2{split($2,a,":"); print a[2]}')
ETH_IP=$(ifconfig eth0 | grep "inet " | awk 'NR!=2{split($2,a,":"); print a[2]}')

case "$1" in
   mjpg)       echo -n "\tStarting streaming video capture (mjpg_streamer -> www)..."
               
               init_mjpg
               
               $MJPG_DIR/mjpg_streamer -i "$MJPG_DIR/input_uvc.so -f 30 -r 640x360 -d /dev/video0" \
                                       -o "$MJPG_DIR/output_http.so -w /tmp/www" \
                                       >/dev/null 2>&1&
               sleep 1

               check_pid "mjpg_streamer"
               exit 0
               ;;

   mjpg_file)  echo -n "\tStarting streaming video capture (mjpg_streamer -> www | file)..."

               init_mjpg

               $MJPG_DIR/mjpg_streamer -i "input_uvc.so -f 15 -d /dev/video0" \
                                       -o "output_file.so -d 70 -c $CONTROL_DIR/plugins/video/prep.sh" \
                                       -o "output_http.so -w /tmp/www" \
                                       >/dev/null 2>&1&
               sleep 1

               check_pid "mjpg_streamer"
               exit 0
               ;;

   vlc)        echo -n "\tStarting video stream (VLC -> rtsp)..."
               su worker -c "cvlc -q --color v4l2:///dev/video0 :v4l2-width=640 :v4l2-height=360 --sout \
                             '#transcode{vcodec=mp4v,vb=1024}:rtp{sdp=rtsp://$WLAN_IP:8554/main.sdp}' \
                             >/dev/null 2>&1&"
               sleep 1

               check_pid "vlc"
               exit 0
               ;;
   
   vlc_file)   echo "\tStarting video stream..."
               
               init_mjpg

               echo -n "\t --Stage 1 (mjpg_streamer -> file | www)..."
               $MJPG_DIR/mjpg_streamer -i "$MJPG_DIR/input_uvc.so -f 30 -r 640x360 -d /dev/video0" \
                                       -o "output_file.so -d 70 -c $CONTROL_DIR/plugins/video/prep.sh" \
                                       -o "$MJPG_DIR/output_http.so -w /tmp/www" \
                                       >/dev/null 2>&1&
               sleep 1

               check_pid "mjpg_streamer"

               echo -n "\t --Stage 2 (www -> VLC -> rtsp)..."

               su worker -c "cvlc -q \"http://localhost:8080/?action=stream\" --sout \
                             '#transcode{vcodec=mp4v,vb=1024}:rtp{sdp=rtsp://$WLAN_IP:8554/main.sdp}' \
                             >/dev/null 2>&1&"
               
               sleep 1
               check_pid "vlc"

               exit 0
               ;;

   stop)       stop_pid "mjpg_streamer"
               stop_pid "vlc"

               exit 0;
               ;;

   *)          echo "Invalid Option!"
               echo "\n\nUsage : $0 {mjpg|mjpg_file|vlc|stop}"
               exit 1
esac

exit 0
