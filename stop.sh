#!/usr/bin/env bash

ps aux | grep ruby.api | grep -v grep | awk '{print $2}' | xargs kill
