#!/usr/bin/env bash
# Conservative IPv4 validation for the managed-domain activation path.
arsy_is_valid_ipv4() {
  local address="${1:-}" a b c d octet
  [[ "$address" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  IFS=. read -r a b c d <<< "$address"
  for octet in "$a" "$b" "$c" "$d"; do
    (( 10#$octet <= 255 )) || return 1
  done
}
arsy_ipv4_integer() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  printf '%u' "$(( (10#$a << 24) | (10#$b << 16) | (10#$c << 8) | 10#$d ))"
}
arsy_ipv4_in_cidr() {
  local address="$1" cidr="$2" network prefix ip_num network_num mask
  IFS=/ read -r network prefix <<< "$cidr"
  [[ "$prefix" =~ ^[0-9]+$ ]] || return 1
  arsy_is_valid_ipv4 "$address" || return 1
  arsy_is_valid_ipv4 "$network" || return 1
  (( prefix >= 0 && prefix <= 32 )) || return 1
  ip_num="$(arsy_ipv4_integer "$address")"
  network_num="$(arsy_ipv4_integer "$network")"
  if (( prefix == 0 )); then mask=0; else mask=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF )); fi
  (( (ip_num & mask) == (network_num & mask) ))
}
arsy_is_global_ipv4() {
  local address="${1:-}" cidr
  arsy_is_valid_ipv4 "$address" || return 1
  local blocked=(
    "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8"
    "169.254.0.0/16" "172.16.0.0/12" "192.0.0.0/24"
    "192.0.2.0/24" "192.31.196.0/24" "192.52.193.0/24"
    "192.88.99.0/24" "192.168.0.0/16" "192.175.48.0/24"
    "198.18.0.0/15" "198.51.100.0/24" "203.0.113.0/24"
    "224.0.0.0/4" "240.0.0.0/4"
  )
  for cidr in "${blocked[@]}"; do
    arsy_ipv4_in_cidr "$address" "$cidr" && return 1
  done
  return 0
}
