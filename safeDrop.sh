#!/bin/bash
# Author           : Maciej Sztramski ( maciejsztramski@gmail.com )
# Created On       : 21.04.2021
# Last Modified By : Maciej Sztramski ( maciejsztramski@gmail.com )
# Last Modified On : 12.05.2021
# Version          : 1.0
#
# Description      : Encrypt and save data for sharing in your dropbox account
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)



source key.sh
filename=''
name=''
option=''
gpgFile=''
link=''
download=''


help() {
	echo "Syntax: ./safeDrop [-h|v]"
	echo "h		Print help."
	echo "v		Print version."
	echo "This program is used to encrypt data and send it to your/default dropbox account."
	echo "There is an added feature which allows user to download and decrypt the files from dropbox via shared links."
	echo ""
	echo "In order to Encrypt folders it is required to ZIP the folder and then encrypt it."
}

version() {
	echo "SafeDrop version: 1.0"
}

changeKey() {
dialog  --stdout --title "change" --yesno "Change key?" 10 20
if [ $? -eq 0 ]; then
	setKey
fi
}

setKey() {
key=`dialog --stdout --title "Enter key:" --inputbox "key" 10 100`
if [ $? -ne 0 ]; then
error "cancel key"
exit
fi
}

error() {
local errorType=$1
dialog --title "error" --msgbox "$1" 6 20
}

download() {
link=`dialog --stdout --title "Enter shared link:" --inputbox "link" 10 100`
if [ $? -ne 0 ]; then
error "cancel download"
exit
fi
download=`curl -s -X POST https://api.dropboxapi.com/2/sharing/get_shared_link_metadata \
    --header "Authorization: Bearer $key" \
    --header "Content-Type: application/json" \
    --data "{\"url\": \"$link\"}" | cut -d '"' -f 16`

if [[ "$download" == *"error"* ]]; then 
	error "Can't download file"
	exit	
fi

curl -s -X POST https://content.dropboxapi.com/2/sharing/get_shared_link_file \
    --header "Authorization: Bearer $key" \
    --header "Dropbox-API-Arg: {\"url\": \"$link\"}" >> $download.gpg
}

upload() {
upload=`curl -s -X POST https://content.dropboxapi.com/2/files/upload \
	--header "Authorization: Bearer $key" \
	--header "Dropbox-API-Arg: {\"path\": \"/BashTestApp/main/$name\",\"mode\": \"overwrite\",\"autorename\": true,\"mute\": false}" \
	--header "Content-Type: application/octet-stream" \
	--data-binary @"$gpgFile"`

if [[ "$upload" == *"error"* ]]; then 
	error "Can't upload file"
	exit
else 
	createLink
fi
}

createLink() {
curl -s -X POST https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings \
	--header "Authorization: Bearer $key" \
	--header "Content-Type: application/json" \
	--data "{\"path\": \"/BashTestApp/main/$name\",\"settings\": {\"requested_visibility\": \"public\",\"audience\": \"public\",\"access\": \"viewer\"}}" >> /dev/null
}

getLink() {
link=$(curl -s -X POST https://api.dropboxapi.com/2/sharing/list_shared_links \
	    --header "Authorization: Bearer $key" \
	    --header "Content-Type: application/json" \
	    --data "{\"path\": \"/BashTestApp/main/$name\"}" | cut -d '"' -f 10)

firefox $link
}

setFilename() {
filename=`dialog --title "Select file" --stdout --title "Please choose a file to encrypt" --fselect $PWD 15 45`
if [ $? -ne 0 ]; then
error "cancel filename"
exit
fi
name=$(basename $filename)
gpgFile="$filename.gpg"
}

removeEncrypted() {
if [ -f $gpgGile]; then
rm -f $gpgFile
fi
}

removeDownload() {
if [ -f $download.gpg ]; then
rm -f $download.gpg
fi
}

removeZipped() {
if [ -f $filename.gpg ]; then
rm -f $filename.gpg
fi
}

decrypt() {
gpg --output enc.$download --decrypt $download.gpg
rm $download.gpg
}

encrypt() {
removeEncrypted
cypherOptions
gpg --output $filename.gpg --symmetric --force-mdc --cipher-algo $algorithmOpt $filename
}

zipFile() {
dialog --stdout --title "zip" --yesno "Zip file?" 10 20
if [ $? -eq 0 ]; then
	zip "$filename.zip" $filename
	filename=$filename.zip
	name=$name.zip
	gpgFile=$filename.gpg
	echo $filename
fi

}

cypherOptions(){
algorithmOpt=`dialog --stdout --title "ENCRYPTION" --radiolist "choose type" 15 60 4 AES256 "AES256" on TWOFISH "TWOFISH" off CAMELLIA256 "CAMELLIA256" off CAST5 "CAST5" off`
if [ $? -ne 0 ]; then
error "Canceled options"
exit
fi
}



menu() {
local opt=`dialog --stdout --title "ENCRYPTION" --radiolist "choose type" 15 60 2 1 "ENCRYPT" on 2 "DECRYPT" off `
if [ $? -ne 0 ]; then
error "Canceled menu"
exit
fi
case "$opt" in
	"1")	setFilename
		changeKey
		zipFile
		encrypt
		upload
		getLink
		removeEncrypted
		removeZipped  ;;

	"2")	changeKey	
		download
		decrypt
		removeDownload ;;
esac
}


while getopts ":hv" opt; do
    case ${opt} in
        h ) help
            exit;;
        v ) version
            exit;;
        * ) echo "Invalid option" 
            exit;;
    esac
done

menu
