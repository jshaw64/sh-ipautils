#!/bin/bash

PLB=/usr/libexec/PlistBuddy

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

set_ent_app_id()
{
  local team_id="$1"
  local app_id="$2"
  local plist="$3"

  set_attribute "application-identifier" "${team_id}.${app_id}" "$plist"
}

set_ent_team_id()
{
  local id="$1"
  local plist="$2"

  set_attribute "com.apple.developer.team-identifier" "$id" "$plist"
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

get_ent_app_id()
{
  local plist="$1"

  get_attribute "application-identifier" "${plist}"
}

get_ent_team_id()
{
  local plist="$1"

  get_attribute "com.apple.developer.team-identifier" "${plist}"
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

ipa_sign_payload()
{
  local sign_id="$1"
  local entitlements_path="$2"
  local payload_dir_app="$3"

  local sig_dir="${payload_dir_app}/_CodeSignature"
  if [ -d "$sig_dir" ]; then
    return  $E_SIG
  fi

  codesign -f -s "$sign_id" --entitlements "$entitlements_path" "$payload_dir_app"

  sig_dir="${payload_dir_app}/_CodeSignature"
  if [ ! -d "$sig_dir" ]; then
    return  $E_SIG
  fi

  return 0
}

ipa_sign_frameworks()
{
  local sign_id="$1"
  local entitlements_path="$2"
  local frameworks_dir="$3"

  codesign -f -s "$sign_id" --entitlements "$entitlements_path" $payload_dir_app

  return 0
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

  return 0
}

get_entitlements_path()
{
  local payload_app_dir="$1"
  local payload_unpack_dir="$2"
  local entitlements_src_dir=""
  local entitlements_src_file="Entitlements.plist"
  local entitlements_src_path=""

  if [ -e "${payload_app_dir}/${entitlements_src_file}" ]; then
    entitlements_src_dir="${payload_app_dir}"
    entitlements_src_path="${entitlements_src_dir}/${entitlements_src_file}"
  elif [ -e "${entitlements_src_dir_payload}/${entitlements_src_file}" ]; then
    entitlements_src_dir="${payload_unpack_dir}"
    entitlements_src_path="${entitlements_src_dir}/${entitlements_src_file}"
  else
    entitlements_src_path=""
  fi

  echo "${entitlements_src_path}"
}

print_entitlements()
{
  local payload_app_dir="$1"

  codesign -d --entitlements :- "$1"
}

print_mobileprovision()
{
  local embedded_prov_path="$1"

  security cms -D -i "$embedded_prov_path"
}
