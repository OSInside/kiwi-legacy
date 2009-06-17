#!/bin/bash
echo "installing library to /usr/local/lib"
cp ./install/PDF.jar /usr/local/lib/

echo "installing binaries to /usr/local/bin"
cp ./install/joinPDF /usr/local/bin
cp ./install/splitPDF /usr/local/bin

