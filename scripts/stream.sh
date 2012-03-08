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
      echo "Failed!!"
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
   
   echo "\nKilling $1..."

   if [ -n "$PID" ]; then
      kill -9 $PID
      echo "Done."
   else
      echo "Not necessary."
   fi
}

if [ $# -lt 1 ]
then
   echo "Usage : $0 {mjpg|mjpg_file|vlc|stop}"
   exit 1
fi

MJPG_DIR=/usr/share/mjpg-streamer
CONTROL_DIR=/root/code/control_auto

case "$1" in
   mjpg)       echo -n "--Starting streaming video capture (mjpg_streamer -> www)..."
               
               init_mjpg
               
               $MJPG_DIR/mjpg_streamer -i "$MJPG_DIR/input_uvc.so -f 15 -d /dev/video0" \
                                       -o "$MJPG_DIR/output_http.so -w $MJPG_DIR/www" \
                                       >/dev/null 2>&1&
               sleep 1

               check_pid "mjpg_streamer"
               exit 0
               ;;

   mjpg_file)  echo -n "--Starting streaming video capture (mjpg_streamer -> www + file)..."

               init_mjpg

               $MJPG_DIR/mjpg_streamer -i input_uvc.so \
               -o "output_file.so -d 70 -c $CONTROL_DIR/clVidFramePrep.sh" \
               -o "output_http.so -w $MJPG_DIR/www" \
               >/dev/null 2>&1&

               sleep 1

               check_pid "mjpg_streamer"
               exit 0
               ;;

   vlc)        echo -n "--Starting video stream (VLC -> rtsp)..."
               su worker -c "cvlc -q --color v4l2:///dev/video0 :v4l2-width=640 :v4l2-height=360 --sout \
                             '#transcode{vcodec=mp4v,vb=1024}:rtp{sdp=rtsp://192.168.1.5:8080/test.sdp}' \
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
