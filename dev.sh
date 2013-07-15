#!/bin/sh  
f="simploo.lua"
tmpf="`mktemp /tmp/onchange.XXXXX`"  
cp "$f" "$tmpf"  
trap "rm $tmpf; exit 1" 2  
while : ; do  
    if [ "$f" -nt "$tmpf" ]; then  
        cp "$f" "$tmpf"  
	cat simploo.lua | luajit
    fi  
    sleep 0.2
done  
