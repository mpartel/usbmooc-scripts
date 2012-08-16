#!/bin/bash -e

. `dirname "$0"`/common.sh

ROOT="$MOUNTPOINT"

mount_image

echo "Cleaning..."

for homedir in "$ROOT"/home/* "$ROOT"/root; do
    cd $homedir
    rm -f .ssh/known_hosts
    rm -f .bash_history
    rm -f .local/share/recently-used.xbel
    
    if [ -d .mozilla/firefox ]; then
        for profile in .mozilla/firefox/*.default; do
            rm -Rf $profile/*Cache $profile/minidumps $profile/cookies.* $profile/formhistory.* $profile/downloads.*
            if [ -f $profile/places.sqlite ]; then
                sqlite3 $profile/places.sqlite 'delete from moz_favicons'
                sqlite3 $profile/places.sqlite 'delete from moz_historyvisits'
            fi
        done
    fi
    
    if [ -d .netbeans/* ]; then
        rm -Rf .netbeans/*/config/tmc
        rm -f .netbeans/*/config/Preferences/fi/helsinki/cs/tmc.properties
    fi
    
    cd "$OLDPWD"
done

rm -Rf "$ROOT"/tmp/*
rm -Rf "$ROOT"/var/tmp/*
rm -Rf "$ROOT"/var/cache/apt
