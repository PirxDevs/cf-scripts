#!/bin/bash

# Copyright (C) 2026 Pirx Developers - https://pirx.dev/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage() {
  cat <<EOF
Usage: $(basename "$0") -z DNS_ZONE

Options:
  -z <zone> - name of DNZ zone to edit
  -h - show this help
EOF
  exit 0
}

script_dir="$(realpath "${0}")"
script_dir="$(dirname "${script_dir}")"

if test -f "${script_dir}/shared"; then
  . "${script_dir}/shared"
else
  echo "Shared code file not found or not readable"
  exit 1
fi

while getopts ":z:h" option; do
  case "${option}" in
    z) zone="${OPTARG}" ;;
    h) usage ;;
    :)
      echo "Error: option -${OPTARG} requires an argument"
      exit 1
      ;;
    \?)
      echo "Error: invalid option -${OPTARG}"
      exit 1
      ;;
  esac
done

if [ -z "${zone}" ]; then
  usage
fi

api_data=$(cf_api GET "zones?name=${zone}") || bail_out "${api_data}"
if [ $(echo "${api_data}" | jq -r '.result_info["count"]') -eq 0 ]; then
  echo "DNS zone ${zone} not found"
  exit 1
fi

zone_id=$(echo "${api_data}" | jq -r '.result[0].id')
if [ -z "${zone_id}" ]; then
  echo "Error getting DNS zone id"
  exit 1
fi

echo -n "Setting SSL/TLS mode to Full (Strict) ... "
data='{"value":"strict"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/ssl" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling Always Use HTTPS ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/always_use_https" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling HSTS ... "
data='{
  "value":{
    "strict_transport_security":{
      "enabled":true,
      "max_age":15552000,
      "include_subdomains":false,
      "preload":false,
      "nosniff":true
    }
  }
}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/security_header" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Setting minimum TLS version to 1.2 ... "
data='{"value":"1.2"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/min_tls_version" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling Opportunistic Encryption ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/opportunistic_encryption" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling TLS 1.3 ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/tls_1_3" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling Automatic HTTPS Rewrites ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/automatic_https_rewrites" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling AI Labyrinth and blocking AI bots ... "
data='{
  "crawler_protection":"enabled",
  "ai_bots_protection":"block",
  "enable_js":true,
  "fight_mode":true
}'
api_data=$(cf_api PUT "zones/${zone_id}/bot_management" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling Browser Integrity Check ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/browser_check" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Enabling Email Address Obfuscation ... "
data='{"value":"on"}'
api_data=$(cf_api PATCH "zones/${zone_id}/settings/email_obfuscation" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

exit 0
