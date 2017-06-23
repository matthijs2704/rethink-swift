#!/usr/bin/env bash

VERSION="3.1.1"
echo "Swift $VERSION Continuous Integration";

# Determine OS
UNAME=`uname`;
if [[ $UNAME == "Darwin" ]];
then
    OS="macos";
else
    if [[ $UNAME == "Linux" ]];
    then
        UBUNTU_RELEASE=`lsb_release -a 2>/dev/null`;
        if [[ $UBUNTU_RELEASE == *"15.10"* ]];
        then
            OS="ubuntu1510";
        else
            OS="ubuntu1404";
        fi
    else
        echo "Unsupported Operating System: $UNAME";
    fi
fi
echo "🖥 Operating System: $OS";

if [[ $OS != "macos" ]];
then
    echo "📚 Installing Dependencies"
    source /etc/lsb-release && echo "deb http://download.rethinkdb.com/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/rethinkdb.list
    wget -qO- https://download.rethinkdb.com/apt/pubkey.gpg | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install -y clang libicu-dev uuid-dev rethinkdb
    eval "$(curl -sL https://apt.vapor.sh)"

    echo "🐦 Installing Swift";
    sudo apt-get install -y swift ctls rethinkdb
else
    echo "📚 Installing Dependencies"
    brew tap vapor/homebrew-tap
    brew update
    brew install vapor rethinkdb
fi

echo "🎛️ Starting RethinkDB server"
rethinkdb --daemon

echo "📅 Version: `swift --version`";

echo "🚀 Building";
swift build
if [[ $? != 0 ]]; 
then 
    echo "❌  Build failed";
    exit 1; 
fi

echo "💼 Building Release";
swift build -c release
if [[ $? != 0 ]]; 
then 
    echo "❌  Build for release failed";
    exit 1; 
fi

echo "🔎 Testing";

swift test
if [[ $? != 0 ]]; 
then 
    echo "❌ Tests failed";
    exit 1; 
fi

echo "🛑 Stopping RethinkDB";
killall rethinkdb

echo "✅ Done"
