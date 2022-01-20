#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

config_file=~/.aws/mfa-config

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [configure|token] [-h] [...]

Available commands:
  configure
  token

Regenerate session aws credentials with MFA token and saves it to aws profile
if no command provided, `token` command is used by default; see  $(basename "${BASH_SOURCE[0]}") token -h

Available options:

-h, --help      Print this help and exit
EOF
  exit
}

usage_configure() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") configure [-h] [-f from_profile] [-t to_profile] [-d duration] -s serial_device

Saves basic mfa-regeneration configuration to ~/.aws/mfa-config

Available options:

-h, --help          Print this help and exit
-f, --from_profile  Which aws profile to use to generate session token. If
                    omitted, then "default". Should differ from --to-profile.

-t, --to_profile    In which aws profile to store session token. If omitted,
                    then "default". Should differ from --from-profile. WARNING!
                    Destination profile credentials would be rewritten!

-d, --duration      Token TTL, default 129600 seconds (36 hours).
-s, --serial        Arn of MFA device serial to use.  Can be taken from
                    https://console.aws.amazon.com/iam/home?region=us-east-1#/security_credentials
EOF
  exit
}

usage_token() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [token] [-h] [--from from_profile] [--to to_profile] [-d duration] [-s serial_device] mfa-token

Script description here.

Available options:

-h, --help          Print this help and exit
-f, --from_profile  Which aws profile to use to generate session token. If
                    present then override configured value (see
                    $(basename "${BASH_SOURCE[0]}") configure -h
                    ). Should differ from --to-profile.

-t, --to_profile    In which aws profile to store session token. If
                    present then override configured value (see
                    $(basename "${BASH_SOURCE[0]}") configure -h
                    ). Should differ from --from-profile. WARNING!
                    Destination profile credentials would be rewritten!

-d, --duration      Token TTL, default 129600 seconds (36 hours). If present
                    then  If present then override configured value.
-s, --serial        Arn of MFA device serial to use. If present then override
                    configured value. Can be taken from
                    https://console.aws.amazon.com/iam/home?region=us-east-1#/security_credentials
mfa-token           one-time 6-digits token from MFA device
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}


parse_params_configure() {
  serial_device=''
  from_profile='default'
  to_profile='default'
  duration=129600

  while :; do
    case "${1-}" in
    -h | --help) usage_configure ;;
    --no-color) NO_COLOR=1 ;;
    -s | --serial) #
      serial_device="${2-}"
      shift
      ;;
    -f | --from) #
      from_profile="${2-}"
      shift
      ;;
    -t | --to) # example named parameter
      to_profile="${2-}"
      shift
      ;;
    -d | --duration) # example named parameter
      duration="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")
  if [[ ${#args[@]} -gt 0 ]]; then
    die "No arguments expected in configure mode"
  fi
}

parse_params_token() {
  if test -f "$config_file"; then
    export $(grep -v '^#' $config_file | xargs -d '\n')
  fi
  from_profile="${MFA_FROM_PROFILE-default}"
  to_profile="${MFA_TO_PROFILE-default}"
  serial_device="${MFA_SERIAL-}"
  duration="${MFA_DURATION-129600}"
  token=''

  while :; do
    case "${1-}" in
    -h | --help) usage_token ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -f | --from) #
      from_profile="${2-}"
      shift
      ;;
    -t | --to) # example named parameter
      to_profile="${2-}"
      shift
      ;;
    -s | --serial_device) #
      serial_device="${2-}"
      shift
      ;;
    -d | --duration) # example named parameter
      duration="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
#  [[ -z "${param-}" ]] && die "Missing required parameter: param"
  if [[ ${#args[@]} -gt 1 ]]; then
    die "Too much arguments; only one token expected"
  fi
  if [[ ${#args[@]} -eq 0 ]]; then
    die "Missing token"
  fi
  token="${args[0]}"
}

parse_params() {
  command='token'
  case "${1-}" in
  -h | --help) usage ;;
  configure)
    command="${1-}"
    shift
    parse_params_configure "$@"
    ;;
  token)
    command="${1-}"
    shift
    parse_params_token "$@"
    ;;
  *)
    parse_params_token "$@"
    ;;
  esac
}

validate_params() {
  if [[ "${from_profile}" == "${to_profile}" ]]; then
   die "Source and destination profile should differ as destination credentials would be overwritten"
  fi
  if [[ ${duration} -gt 129600 ]]; then
    die "Duration cannot be greater than 129600 sec (36 hours). That is an AWS restriction."
  fi
}

configure_cmd() {
  msg "- from: ${from_profile}"
  msg "- to: ${to_profile}"
  msg "- serial: ${serial_device}"
  msg "- duration: ${duration}"

  validate_params

  touch $config_file
  echo "MFA_SERIAL=${serial_device}" > $config_file
  echo "MFA_FROM_PROFILE=${from_profile}" >> $config_file
  echo "MFA_TO_PROFILE=${to_profile}" >> $config_file
  echo "DURATION=${duration}" >> $config_file

  msg "Configuration saved"
}

token_cmd() {
  msg "- from: ${from_profile}"
  msg "- to: ${to_profile}"
  msg "- serial: ${serial_device}"
  msg "- duration: ${duration}"
  msg "- token: ${token}"

  validate_params
  [[ -z ${serial_device} ]] && die "Missed serial device"

}

parse_params "$@"
setup_colors

msg "${RED}Read parameters:${NOFORMAT}"

msg "command: ${command}"

case "${command}" in
  configure) configure_cmd ;;
  token) token_cmd ;;
esac

cleanup