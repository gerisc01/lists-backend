#!/usr/bin/env bash
if [ -z "$1" ]
  then
    rake test
elif [ -z "$2" ]
  then
    testfile=$(find . -name $1.rb)
    rake test TEST=$testfile
else
  testfile=$(find . -name $1.rb)
  rake test TEST=$testfile TESTOPTS="--name=$2 -v"
fi