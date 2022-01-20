# About
If you use MFA on your AWS account, some operations 
[may not be available](https://aws.amazon.com/ru/premiumsupport/knowledge-center/authenticate-mfa-cli/) to run 
from CLI with usual Access key / secret key credentials. You may need to generate a temporary session credentials 
to use CLI in full strength.

This `aws-mfa` script simplifies the process: it allows you to regenerate credentials in one command and store them to
the predefined aws-cli profile.

# Usage

## Configure

Stores some often used arguments to config file (`~/.aws/mfa-config`)

```shell
./aws-mfa.sh configure [-h] [-f from_profile] [-t to_profile] [-d duration] -s serial_device
```

* `-f | --from` : which `aws-cli` profile to use for generating temporary token. `default` profile is used by default.
* `-t | --to`: in which `aws-cli` profile to store generated credentials. `default` profile is used by default. 
Remember, this profile credentials would be overwritten on every session token issuing!
* `-d | --duration`: session token TTL in seconds. Cannot be greater than 129 secs == 36 hours (AWS restriction).
* `-s | --serial`: ARN of MFA device that would be used to generate session credentials. Can be found at https://console.aws.amazon.com/iam/home?region=us-east-1#/security_credentials

## (Re-)generate a new credentials

```shell
./aws-mfa.sh [-f from_profile] [-t to_profile] [-d duration] [-s serial_device] mfa-token
```

Regenerates a new session credentials using configured data and your one-time mfa-token. Stores them in `--to` `aws-cli`-profile. Used params override stored config values.

# Examples: generated profiles usage

## Ex1

Constant credentials saved at `aws-creds-constant`, and we want to use `default` profile for any aws-cli operations

```shell
./aws-mfa.sh configure --from aws-creds-constant --serial arn:aws:iam::123456789012:mfa/login@email.com
./aws-mfa.sh 123456  # regenerates credentials, store them in `default` profile
aws s3 ls s3://your-bucket/  # use default profile for aws-cli operations
```

## Ex2

Constant credentials are saved at `default` profile and usually we use `default` profile for actions not requiring MFA.
We want to create new / reuse `aws-creds-mfa` profile for any aws-cli operations that require MFA.

```shell
./aws-mfa.sh configure --to aws-creds-mfa --serial arn:aws:iam::123456789012:mfa/login@email.com 
./aws-mfa.sh 123456  # regenerates credentials, store them in `aws-creds-mfa` profile
aws --profile aws-creds-mfa s3 ls s3://your-bucket/  # use mfa profile when needed
```
