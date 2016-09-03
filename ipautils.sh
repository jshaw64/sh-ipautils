#!/bin/bash

PLB=/usr/libexec/PlistBuddy

toggle_log_redir()
{
	case $1 in
		1 )
			exec 6<&1
			exec >> $LOG_FILE
			;;
		0 )
			exec 1<&6 6>&-
			;;
	esac
}

set_attribute()
{
  local query="$1"
  local value="$2"
  local plist="$3"

  $PLB -c "Set :$query $value" "$plist"
}

set_cfbundleversion()
{
  local version="$1"
  local plist="$2"

  set_attribute "CFBundleVersion" "$version" "$plist"
}

set_cfbundleshortversion()
{
  local version="$1"
  local plist="$2"

  set_attribute "CFBundleShortVersionString" "$version" "$plist"
}

set_cfbundleid()
{
  local id="$1"
  local plist="$2"

  set_attribute "CFBundleIdentifier" "$id" "$plist"
}

get_attribute()
{
  local query="$1"
  local plist="$2"
  local attr=

  attr=$($PLB -c "Print $query" "$plist")

  echo "$attr"
}

get_cfbundleversion()
{
  local plist="$1"

  get_attribute "CFBundleVersion" "$plist"
}

get_cfbundleshortversion()
{
  local plist="$1"

  get_attribute "CFBundleShortVersionString" "$plist"
}

get_cfbundleid()
{
  local plist="$1"

  get_attribute "CFBundleIdentifier" "$plist"
}

generate_entitlements()
{
  local entitlements_dir_src="$1"
  local entitlements_dir_dst="$2"
  local entitlements_file_name="$3"
  local bundle_id="$4"
  local team_id="$5"

  local entitlements_file_src="${entitlements_dir_src}/${entitlements_file_name}"
  local entitlements_file_dst="${entitlements_dir_dst}/${entitlements_file_name}"
  local inject_str="<string>${team_id}.${bundle_id}</string>"
  local inject_key="string"

  local tmp_str=
  while read -r line || [ -n "$line" ]; do
    tmp_str=${line%%>*}
    tmp_str=${tmp_str#<*}
    if [ "$tmp_str" = "$inject_key" ]; then
     line="$inject_str"
    fi
    echo "$line" >> $entitlements_file_dst
  done < "$entitlements_file_src"

  echo "$entitlements_file_dst"
}

increment_v_sem()
{
:
  #VERSIONNUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PROJECT_DIR}/${INFOPLIST_FILE}")
  #NEWSUBVERSION=`echo $VERSIONNUM | awk -F "." '{print $3}'`
  #NEWSUBVERSION=$(($NEWSUBVERSION + 1))
  #NEWVERSIONSTRING=`echo $VERSIONNUM | awk -F "." '{print $1 "." $2 ".'$NEWSUBVERSION'" }'`
}

increment_v_dec()
{
  local version=$1
  local version_incremented=$2
  local v_before=${version%.*}
  local v_after=${version##*.}

  # v=.123 or v=123
  if [ -z $v_before -o $v_before = $version ]; then
    v_before="0"
  fi

  let "v_after = 10#$v_after + 1"
  local v_final="${v_before}.${v_after}"

  echo "$v_final"
}

increment_v_int()
{
  local version=$1

  local v_final=$version
  let "v_final = 10#$v_final + 1"

  echo "$v_final"
}


increment()
{
  local version="$1"
  local v_final=

  # version="1.3.01170"
  # version=".01170"
  # version="01170"
  # version="01170."
  case $version in 
    *[\.]* )
       v_final=$(increment_v_dec $version)
       ;;
    * )
       v_final=$(increment_v_int $version)
       ;;
  esac

  echo "$v_final"

}

payload_pack()
{
	local tmp_dir="$1"
	local payload_dir_root="$2"
	local binary_out_dir="$3"
	local binary_out_fname="$4"
	local binary_out_path="${binary_out_dir}/${binary_out_fname}"

	(( DEBUG )) && echo "Packaging payload [$payload_dir_root] to [$binary_out_path]"

	(
	cd "$tmp_dir"
	zip -qr "$binary_out_fname" "./Payload"
	cp "$binary_out_fname" "$binary_out_path"
	)

	if [ ! -e "$binary_out_path" ]; then
		(( DEBUG || VERBOSE )) && echo "There was an issue packaging, can't find [$binary_out_path]"
		exit "$E_BINARY"
	fi

	(( DEBUG )) && echo "Binary [$binary_out_path] created successfully"
}

payload_sign()
{ 
	local sign_id="$1"
	local entitlements_path="$2"
	local payload_dir_app="$3"

	(( DEBUG )) && echo "Signing payload [$payload_dir_app] with identity [$sign_id] and entitlements [$entitlements_path]"

	codesign -f -s "$sign_id" --entitlements "$entitlements_path" "$payload_dir_app" > /dev/null

	local sig_dir="${payload_dir_app}/_CodeSignature"
	if [ ! -d "$sig_dir" ]; then
		(( DEBUG || VERBOSE )) && echo "Something went wrong signing, can't find sig dir [$sig_dir]"
		exit $E_SIG
	fi

	(( DEBUG )) && echo "Signing successful, found sig dir [$sig_dir]"
}

payload_sig_rm()
{
	local payload_dir_app="$1"
	local sig_dir="${payload_dir_app}/_CodeSignature"

	if [ ! -d "$sig_dir" ]; then
		(( DEBUG || VERBOSE )) && echo "Can't find sig dir [$sig_dir]"
		exit $E_SIG
	fi

	(( DEBUG )) && echo "Found sig dir [$sig_dir]"
	(( DEBUG )) && echo "Deleting sig dir..."

	rm -r "$sig_dir"

	if [ -d "$sig_dir" ]; then
		(( DEBUG || VERBOSE )) && echo "Something went wrong deleting [$sig_dir]"
		exit $E_SIG
	fi

	(( DEBUG )) && echo "Sig dir deleted successfully"
}

get_payload_dir_app()
{
	local payload_dir_root="$1/Payload"
	local payload_dir_app=

	for dir in $payload_dir_root/*; do
		payload_dir_app="$dir"
	done


	echo "$payload_dir_app"
}


prepare_plist()
{
	local payload_dir_app="$1"
	local src_path="${payload_dir_app}/${SRC_FILE}"

	toggle_log_redir 1

	if [ ! -e "$src_path" ]; then
		(( DEBUG || VERBOSE )) && echo "Can't find plist file [$src_path]"
		exit $E_SRC_FILE
	fi

	(( DEBUG || VERBOSE )) && echo "Found plist file [$src_path]"

	toggle_log_redir 0
	
	echo "$src_path"
}

prepare_profile()
{
	local profile_dir_src="$1"
	local profile_dir_dst="$2"
	local profile_fname_src="$3"
	local profile_fname_dst="embedded.mobileprovision"
	local profile_file_src="${profile_dir_src}/${profile_fname_src}"
	local profile_file_dst="${profile_dir_dst}/${profile_fname_dst}"



	cp "$profile_file_src" "$profile_file_dst"

	if [ ! -e "$profile_file_dst" ]; then
		exit $E_PROFILE
	fi


	echo "$profile_file_dst"
}

prepare_payload()
{
	local binary_dir_dst="$1"
	local binary_file_name="$2"
	local binary_file_dst="${binary_dir_dst}/${binary_file_name}" # unzip fails on quoted dir

	(( DEBUG )) && echo "Unzipping binary [$binary_file_dst]"

	unzip "$binary_file_dst" -d "$binary_dir_dst" > /dev/null

	local payload_dir_root="${binary_dir_dst}/Payload"

	if [ ! -d "$payload_dir_root" ]; then
		(( DEBUG || VERBOSE )) && echo "Something went wrong unzipping [$binary_file_dst], [$payload_dir_root] does not exist"
		exit $E_PAYLOAD
	fi

	(( DEBUG )) && echo "Found payload dir [$payload_dir_root]"
}

prepare_binary()
{
	local binary_dir_src="$1"
	local binary_dir_dst="$2"
	local binary_file_name="$3"
	local binary_fname_dst="$4"

	local binary_file_src="${binary_dir_src}/${binary_file_name}"
	#local binary_file_dst="${binary_dir_dst}/${binary_fname_dst}"
	local binary_file_dst="${binary_dir_dst}/${binary_file_name}"
	
	if [ ! -e "$binary_file_src" ]; then
		(( DEBUG || VERBOSE )) && echo "Something went wrong with the source binary file [$binary_file_src]"
		exit $E_BINARY
	fi

	(( DEBUG )) && echo "Copying binary from [$binary_file_src] to [$binary_file_dst].."

	cp "$binary_file_src" "$binary_file_dst"

	if [ ! -e "$binary_file_dst" ]; then
		(( DEBUG || VERBOSE )) && echo "Something went wrong with the dest binary file [$binary_file_dst]"
		exit $E_BINARY
	fi
}

prepare_entitlements()
{
	local entitlements_dir_src="$1"
	local entitlements_dir_dst="$2"
	local entitlements_file_name="$3"
	local bundle_id="$4"
	local team_id="$5"

	local entitlements_file_src="${entitlements_dir_src}/${entitlements_file_name}"
	local entitlements_file_dst="${entitlements_dir_dst}/${entitlements_file_name}"
	local inject_str="<string>${team_id}.${bundle_id}</string>"
	local inject_key="string"

	if [ ! -e "$entitlements_file_src" ]; then
		exit $E_ENTITLEMENTS
	fi


	local tmp_str=
	while read -r line || [ -n "$line" ]; do
		tmp_str=${line%%>*}
		tmp_str=${tmp_str#<*}
		if [ "$tmp_str" = "$inject_key" ]; then
#			echo "$inject_str" >> $entitlements_file_dst
			line="$inject_str"
		fi
		echo "$line" >> $entitlements_file_dst
	done < "$entitlements_file_src"


	echo "$entitlements_file_dst"
}
