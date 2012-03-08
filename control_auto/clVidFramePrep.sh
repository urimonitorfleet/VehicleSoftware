#!/bin/bash

IMG="/tmp/cur.jpg"

mv $1 $IMG

/root/code/control_auto/clVidFrame $IMG 2> /dev/null
