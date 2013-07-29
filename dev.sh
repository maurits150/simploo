#!/bin/sh  
f="simploo.lua"
tmpf="`mktemp /tmp/onchange.XXXXX`"  
cp "$f" "$tmpf"  
trap "rm $tmpf; exit 1" 2  
while : ; do  
    if [ "$f" -nt "$tmpf" ]; then  
        cp "$f" "$tmpf"  
	echo "Reloading simploo.lua..."
	cat simploo.lua | luajit
    fi  
    sleep 1
done  
