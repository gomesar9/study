#!/bin/bash

echo "Copying ckf.sh"
cp /git/github/study/clockfly/ckf.sh /opt/ckf/ckf.sh

echo "Linking ckf.sh to /usr/bin/ckf"
sudo ln --force -s /opt/ckf/ckf.sh /usr/bin/ckf

