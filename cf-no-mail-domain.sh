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

api_data=$(cf_api GET "zones/${zone_id}/dns_records") || bail_out "${api_data}"
echo "${api_data}" | jq -r '
  (.result | map(select(.type=="MX") | .content)) as $mx
  | .result[]
  | select(
    (.type=="MX" and .content!=".")
    or
    (.type=="TXT" and (
      (
        (.content | test("v=spf1"; "i"))
        and
        ((.content | test("^\"?v=spf1\\s+-all\"?$"; "i")) | not)
      )
      or (.name | test("^_dmarc\\."; "i"))
      or (.name | test("_domainkey\\."; "i"))
    ))
    or
    (.type=="A" and (.name as $n | any($mx[]; . == $n)))
  )
  | "\(.id) \(.name) \(.type) \(.content)"
' | while read -r record_id record_name record_type record_value; do
  printf "Deleting record: %s IN %s %.16s ... " "${record_name}" "${record_type}" "${record_value}"
  api_data=$(cf_api DELETE "zones/${zone_id}/dns_records/${record_id}") && { echo "OK"; } || { error_out "${api_data}"; }
done

echo -n "Adding NULL MX record ... "
data=$(jq -n \
  --arg name "${zone}" \
  '{type: "MX", name: $name, content: ".", ttl: 1, priority: 0, proxied: false}')
api_data=$(cf_api POST "zones/${zone_id}/dns_records" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

echo -n "Adding SPF record ... "
data=$(jq -n \
  --arg name "${zone}" \
  '{type: "TXT", name: $name, content: "\"v=spf1 -all\"", ttl: 1, priority: 0, proxied: false}')
api_data=$(cf_api POST "zones/${zone_id}/dns_records" "${data}") && { echo "OK"; } || { error_out "${api_data}"; }

exit 0
