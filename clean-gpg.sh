#!/bin/bash
# Clean up the GPG Keyring.  Keep it tidy.

filter="^pub:[r|e]:"

echo -n "Expired and revoked Keys: "
for expiredKey in $(gpg2 --list-keys --fixed-list-mode --with-colons  | grep "^pub" | grep "$filter" | cut -f5 -d":" | fmt -w 999); do
    echo -n "$expiredKey"
    if ! gpg2 --batch --yes --quiet --delete-keys "$expiredKey" >/dev/null 2>&1; then
        echo -n "(OK), "
    else
        echo -n "(FAIL), "
    fi
done
echo done.
echo
echo -n "Update Keys: "
for keyid in $(gpg2 --list-keys --fixed-list-mode --with-colons  | grep "^pub" | grep -v "$filter" | cut -f5 -d":" | fmt -w 999); do
    echo -n "$keyid"
    if ! gpg2 --batch --yes --quiet --edit-key "$keyid" check clean cross-certify save quit > /dev/null 2>&1; then
        echo -n "(OK), "
    else
        echo -n "(FAIL), "
    fi
done
echo done.

if ! gpg2 --batch --quiet --refresh-keys > /dev/null 2>&1; then
    echo "Refresh OK"
else
     echo "Refresh FAIL."
fi
