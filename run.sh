#!/bin/sh

set -ex

url=https://cdist2.perforce.com/perforce/r19.1/bin.macosx1010x86_64/helix-core-server.tgz

curl -I --silent --header 'If-Modified-Since: $(last.modified)' $url | tr -d '\r' >out
first_line=$(head -n 1 <out)
case "$first_line" in
"HTTP/1.1 304 Not Modified")
    ;; # still up to date; nothing needs to be changed
"HTTP/1.1 200 OK")
    # not up to date
    new_last_modified="$(sed -n 's/^Last-Modified: //p' <out)"
    curl --silent -o helix-core-server.tgz $url
    new_version="$(tar Oxvf helix-core-server.tgz Versions.txt | sed -n 's/^Rev\. P4D\/[^\/]*\/20\([^\/]*\)\/\([^ ]*\).*/\1-\2/p')"
    new_sha256="$(openssl dgst -sha256 helix-core-server.tgz)"
    new_sha256="${new_sha256##* }"
    echo "TODO: automatically open a PR with $new_version and $new_sha256, and then update last.modified=$new_last_modified" >&2
    exit 1

    # TODO: open a PR like https://github.com/Homebrew/homebrew-cask/pull/70981

    # Update the last.modified variable in this build definition
    auth_header="Authorization: Bearer $SYSTEM_ACCESSTOKEN"
    url="$SYSTEM_TEAMFOUNDATIONSERVERURI$SYSTEM_TEAMPROJECTID/_apis/build/definitions/$SYSTEM_DEFINITIONID?api-version=5.0"
    original_json="$(curl --silent -H "$auth_header" -H "Accept: application/json; api-version=5.0; excludeUrls=true" "$url")"
    json="$(echo "$original_json" | sed 's/\("last.modified":{"value":"\)[^"]*/\1'"$new_last_modified"/)"
    curl --silent -X PUT -H "$auth_header" -H "Content-Type: application/json" -d "$json" "$url"
    ;;
*)
    echo "Unexpected curl result:" >&2
    cat out >&2
    exit 1
    ;;
esac
