#!/bin/bash

PLB=/usr/libexec/PlistBuddy

set_attribute()
{
  local query="$1"
  local value="$2"
  local value_type="$3"
  local plist="$4"

  $PLB -c "Set :$query $value" "$plist"
  [ $? -gt 0 ] &&  $PLB -c "Add :$query $value_type $value" "$plist"
}

set_cfbundleversion()
{
  local version="$1"
  local plist="$2"

  set_attribute "CFBundleVersion" "$version" "string" "$plist"
}

set_cfbundleshortversion()
{
  local version="$1"
  local plist="$2"

  set_attribute "CFBundleShortVersionString" "$version" "string" "$plist"
}

set_cfbundleid()
{
  local id="$1"
  local plist="$2"

  set_attribute "CFBundleIdentifier" "$id" "string" "$plist"
}

set_ns_photo_usage_desc()
{
  local desc="$1"
  local plist="$2"

  set_attribute "NSPhotoLibraryUsageDescription" "$desc" "string" "$plist"
}

set_ent_app_id()
{
  local team_id="$1"
  local app_id="$2"
  local plist="$3"

  set_attribute "application-identifier" "${team_id}.${app_id}" "string" "$plist"
}

set_ent_team_id()
{
  local id="$1"
  local plist="$2"

  set_attribute "com.apple.developer.team-identifier" "$id" "string" "$plist"
}

set_ent_get_task_allow()
{
  local value="$1"
  local plist="$2"

  set_attribute "get-task-allow" "$value" "bool" "$plist"
}

set_ent_keychain_access()
{
  local team_id="$1"
  local app_id="$2"
  local plist="$3"

  set_attribute "keychain-access-groups" "" "array" "$plist"
  set_attribute "keychain-access-groups:" "${team_id}.${app_id}" "string" "$plist"
}

set_ent_beta_reports_active()
{
  local value="$1"
  local plist="$2"

  set_attribute "beta-reports-active" "$value" "bool" "$plist"
}

set_ent_apns()
{
  local value="$1"
  local plist="$2"

  set_attribute "aps-environment" "$value" "string" "$plist"
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

get_ns_photo_usage_desc()
{
  local plist="$1"

  get_attribute "NSPhotoLibraryUsageDescription " "$plist"
}

get_ent_team_id()
{
  local plist="$1"

  get_attribute "com.apple.developer.team-identifier" "${plist}"
}

get_ent_get_task_allow()
{
  local plist="$1"

  get_attribute "get-task-allow " "$plist"
}

get_ent_beta_reports_active()
{
  local plist="$1"

  get_attribute "beta-reports-active" "$plist"
}

get_ent_apns()
{
  local plist="$1"

  get_attribute "aps-environment" "$plist"
}

get_ent_app_id()
{
  local plist="$1"

  get_attribute "application-identifier" "${plist}"
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
  local payload_dir_app="$2"

  codesign -f -s "$sign_id" "$payload_dir_app"/Frameworks/*

  return 0
}


generate_entitlements()
{
  local entitlements_dst_dir="$1"
  local app_id="$2"
  local team_id="$3"

  local entitlements_file="Entitlements.plist"
  local entitlements_dst_path="${entitlements_dst_dir}/${entitlements_file}"

  set_ent_app_id "${team_id}" "${app_id}" "${entitlements_dst_path}"
  set_ent_team_id "${team_id}" "${entitlements_dst_path}"
  set_ent_get_task_allow "false" "${entitlements_dst_path}"
  set_ent_keychain_access "${team_id}" "*" "${entitlements_dst_path}"

  if [ ! -e "${entitlements_dst_path}" ]; then
    return $E_GEN_ENT
  fi

  return 0
}

generate_entitlements_xcent()
{
  local entitlements_src_dir="$1"
  local entitlements_src_file="$2"
  local entitlements_src_path="${entitlements_src_dir}/${entitlements_src_file}"
  local entitlements_dst_dir_xcent="$3"
  local entitlements_dst_file_xcent="archived-expanded-entitlements.xcent"
  local entitlements_dst_path_xcent="${entitlements_dst_dir_xcent}/${entitlements_dst_file_xcent}"

  if [ ! -e "${entitlements_src_path}" ]; then
    return $E_GEN_ENT
  fi

  cp -f "${entitlements_src_path}" "${entitlements_dst_path_xcent}"

  if [ ! -e "${entitlements_dst_path_xcent}" ]; then
    return $E_GEN_ENT
  fi

  return 0
}

extract_entitlements_from_pp()
{
  local entitlements_dst_path="$1"
  local prov_prof_file_path="$2"

  local entitlements_file_header="$( cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
EOF
)"

  echo "${entitlements_file_header}" > "${entitlements_dst_path}"

  local OIFS=$IFS
  IFS=""

  regexDictBegin="[[:space:]]*<key>Entitlements</key>[[:space:]]*"
  regexDictEnd="[[:space:]]*</dict>[[:space:]]*"

  local start=0

  while read -r line; do
    if [[ $line =~ $regexDictBegin ]]; then
      start=1
    elif [ "$start" = 1 ]; then
      echo "$line" >> "${entitlements_dst_path}"
    fi
    if [[ $line =~ $regexDictEnd ]]; then
      break;
    fi
  done < "${prov_prof_file_path}"

  local entitlements_file_footer="</plist>"
  echo "$entitlements_file_footer" >> "${entitlements_dst_path}"

  IFS=$OIFS
}

get_entitlements_path()
{
  local payload_unpack_dir="$1"
  local payload_app_dir="$2"
  local entitlements_src_dir=""
  local entitlements_src_file="Entitlements.plist"
  local entitlements_src_path=""

  if [ -e "${payload_app_dir}/${entitlements_src_file}" ]; then
    entitlements_src_dir="${payload_app_dir}"
    entitlements_src_path="${entitlements_src_dir}/${entitlements_src_file}"
  elif [ -e "${payload_unpack_dir}/${entitlements_src_file}" ]; then
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
