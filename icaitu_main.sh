#!/bin/bash

path=""
logfile=""
idfile=""
rawidfile=""
since_id=""
rawid=""
SLEEP_INTERVAL=5


function saveSinceID(){
   if [[ ! -z $1 ]]; then
	echo "$1" > $since_id_file
   fi
}

function getSinceID(){
    cat $since_id_file
}

function scriptPath()
{
    readlink -f "$0" |sed -e "s#/[^/]*\$##g"
}

function init(){
    #global vales
    path=`scriptPath`
    logfile="$path/log"
    . $path/config

    since_id_file="$path/sinceid.txt"
    touch $since_id_file

    since_id=`getSinceID`
    loginIcaitu
}

function logger ()
{
    time=`date +"%Y-%m-%d %T"`
    echo "[$time] $*"
}

function loginIcaitu()
{
    if [ -z $ict_password ]; then
	logger "Please set your icaitu UserName and PassWord."
	exit
    fi
    local post_query="LoginForm%5Busername%5D=$ict_username&LoginForm%5Bpassword%5D=$ict_password&LoginForm%5BrememberMe%5D=on"
    logger $post_query
    > $path/cookie.txt
    curl -s -D $path/cookie.txt -d "$post_query" "http://www.icaitu.com/"
    logger "Logged in with cookie $path/cookie.txt"

}

function publish()
{
    local URL="$1"
    local IMG="$2"
    local TEXT="$3"

    local api="http://www.icaitu.com/collect/bookmarkajax"
    local query="boardId=15397&source=$URL&url%5B%5D=$IMG&type=public&caption=$TEXT&sync%5B%5D=tfanfou"
    if [ ! -f $path/cookie.txt ]; then
	logger "You have not logged in!"
	exit
    fi

    curl -s -b "$path/cookie.txt" -d "$query" "$api"
    logger "$IMG published"
    exit

}


function getMaxSinceID(){

    local msgs="$*"
    echo $msgs |grep -oP "(?<=<id>)[^<]+(?=</id>\s+<rawid)" |head -n 1
}

function parseMsgs(){

    local msgs="$*"

    echo $msgs |sed -e "s#<status>#\n<status>#g" |grep -Pvi "@|izibao"|grep largeurl |while read msg
    do
	#echo $msg
	id=`echo $msg |grep -oP "(?<=<id>)[^<]+(?=</id>\s+<rawid)"`
	rawid=`echo $msg |grep -oP "(?<=<rawid>)[^<>]+(?=</rawid>)"`
	url="http://fanfou.com/statuses/$id"
	text=`echo $msg |grep -oP "(?<=<text><!\[CDATA\[).*?(?=\]\])" |sed -e "s#<[^<>]*>##g"`
	img_url=`echo $msg |grep -oP "(?<=<largeurl>)[^<>]+(?=</largeurl>)"`
	if [[ ! -z $id ]]; then
	    logger $rawid $id $url $img_url "\"$text\""
	    publish $url $img_url "$text"
	fi
    done
}

#parseMsgs $msgs
#getMaxSinceID $msgs

init
while true
do
    logger "searching since: $since_id"
    msgs=`curl -s -u $ff_password:$ff_password "http://api.fanfou.com/search/public_timeline.xml?q=自爆|自曝%201&since_id=$since_id" |tr -d '\n' `
    parseMsgs $msgs
    tmp_id=`getMaxSinceID $msgs`
    if [[ ! -z $tmp_id ]]; then
	saveSinceID $since_id
	since_id=$tmp_id
	logger $since_id
    fi

    sleep $SLEEP_INTERVAL
done

logger `/bin/rm -vf $path/cookie.txt`
