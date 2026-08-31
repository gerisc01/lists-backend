#!/usr/bin/env bash
# ALWAYS via `bundle exec` — a bare `rake` resolves gems outside Gemfile.lock, picks up a
# newer Sinatra, and every API test fails `400 Host not permitted`. That reads as 82 real
# failures in your own code, which is exactly how it wastes an afternoon. It has.
if [ -z "$1" ]
  then
    bundle exec rake test
elif [ -z "$2" ]
  then
    testfile=$(find . -name $1.rb)
    bundle exec rake test TEST=$testfile
else
  testfile=$(find . -name $1.rb)
  bundle exec rake test TEST=$testfile TESTOPTS="--name=$2 -v"
fi
