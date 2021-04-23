#!/bin/bash

echo "deb http://security.ubuntu.com/ubuntu bionic-security main" >> /etc/apt/sources.list

apt-get update -y && apt-get install -y --no-install-recommends libssl1.0-dev
