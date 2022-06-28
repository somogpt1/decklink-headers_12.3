#!/bin/bash

guess_dirname() {
    expr "$1" : '\(.\+\)\.\(tar\(\.\(gz\|bz2\|xz\|lz\)\)\?\|7z\|zip\)$'
}

real_extract() {
    local archive="$1" dirName="$2"
    [[ ! $dirName ]] && dirName=$(guess_dirname "$archive" || echo "${archive}")
    7z x -aoa -o"$dirName" "$archive"
    local temp_dir
    temp_dir=$(find "$dirName/" -maxdepth 1 ! -wholename "$dirName/")
    if [[ -n $temp_dir && $(wc -l <<< "$temp_dir") == 1 ]]; then
        find "$temp_dir" -maxdepth 1 ! -wholename "$temp_dir" -exec mv -t "$dirName/" {} +
        rmdir "$temp_dir" 2> /dev/null
    fi
}

do_extract() {
    local archive="$1"
    dirName=$(guess_dirname "$archive")
    real_extract "$archive" "$dirName"
    cd "$dirName" || return 1
}

extract_values_from_aur() (
    {
        curl -Ls https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=decklink-sdk > PKGBUILD
        . PKGBUILD
        cat << EOF
_ver=$pkgver
_referid=$_referid
_downloadid=$_downloadid
EOF
    } || printf 'exit 1\n'
)

downloadDecklink() (
    _arch=Windows

    eval "$(extract_values_from_aur)"

    _siteurl="https://www.blackmagicdesign.com/api/register/us/download/${_downloadid}"
    _useragent='User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:81.0) Gecko/20100101 Firefox/81.0'
    _reqjson="{ \
        \"platform\": \"Windows\", \
        \"country\": \"us\", \
        \"firstname\": \"Deck\", \
        \"lastname\": \"Link\", \
        \"email\": \"mail@example.org\", \
        \"phone\": \"202-555-0194\", \
        \"state\": \"New York\", \
        \"city\": \"MABS\", \
        \"hasAgreedToTerms\": true, \
        \"product\": \"Desktop Video ${_ver} SDK\" \
    }"
    _filename="Blackmagic_DeckLink_SDK_${_ver}.zip"

    _srcurl="$(curl -s -H "$_useragent" -H 'Content-Type: application/json;charset=UTF-8' \
        -H "Referer: https://www.blackmagicdesign.com/support/download/${_referid}/Linux" \
        --data-ascii "$_reqjson" --compressed "$_siteurl")"

    _root=$PWD

    rm -rf build
    mkdir -p build
    cd build || exit 1
    curl -gqb '' -C - --retry 3 --retry-delay 3 -H 'Upgrade-Insecure-Requests: 1' -o "${_filename}" --compressed "${_srcurl}"

    do_extract "$_filename"
    cd Win/include || exit 1
    # add newline at the end of file if it's missing, otherwise widl whines about it
    sed -i -e '$a\' ./*.idl
    widl -I"$MINGW_PREFIX/$MINGW_CHOST/include" -h -u DeckLinkAPI.idl
    sed -n '2,24 s/^\*\*//p' DeckLinkAPI.idl > DeckLinkAPI.LICENSE
    cp DeckLinkAPI{.h,_i.c,Version.h} "$_root"/include/
    cp DeckLinkAPI.LICENSE "$_root"/'SDK License.txt'
)

downloadDecklink
