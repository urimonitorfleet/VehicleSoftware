#!/bin/bash

IMG="/tmp/cur.jpg"

mv $1 $IMG

/root/code/control_auto/plugins/video/gather $IMG 2> /dev/null
