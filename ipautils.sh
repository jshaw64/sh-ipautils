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
  local plist="$1"

  set_attribute "CFBundleVersion" "$version" "$plist"
}

get_attribute()
{
  local query="$1"
  local plist="$2"
  local attr=

  attr=$($PLB -c "Print $query" "$plist")

  echo "$attr"
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

#validate_attr()
#{
#  local validate_attr="$1"
#
#  for attr in "${ATTRIBUTES[@]}"; do
#    [ $attr = $validate_attr ] && return 0
#  done
#
#  return $E_ATTR
#}

#validate_file()
#{
#  local validate_file="$1"
#
#  if [ ! -e "$validate_file" ]; then
#    return $E_INFILE
#  fi
#
#  return 0
#}

