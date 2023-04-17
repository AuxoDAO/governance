#!/bin/bash

# build the slither image
docker build analysis -t slither;

# run the slither image, mounting CWD to buybacks
docker run -it -v $PWD:/work slither:latest

