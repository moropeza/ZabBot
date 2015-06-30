#!/bin/bash

to=$1
subject=$2
body=$3

echo 1:"$to" 2:"$subject" 3:"$body" >> /tmp/tg.log

cd /home/ZabBot

cat << EOF | bundle exec ruby push.rb "$to" "$subject" "$body"
EOF
