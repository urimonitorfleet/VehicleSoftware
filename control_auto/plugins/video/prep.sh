#!/bin/bash

IMG="/tmp/cur.jpg"

mv $1 $IMG

./gather $IMG 2> /dev/null
