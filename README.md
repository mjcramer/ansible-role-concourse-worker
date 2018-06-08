sudo apt-get install postgresql postgresql-contrib




Standalone Binary

At some point you may want to start putting Concourse on to real hardware. A binary distribution is available in the downloads section.

The binary is fairly self-contained, making it ideal for tossing onto a VM by hand or orchestrating it with Docker, Chef, or other ops tooling.

Prerequisites

Grab the appropriate binary for your platform from the downloads section.

For Linux you'll need kernel v3.19 or later, with user namespace support enabled. Windows and Darwin don't really need anything special.

PostgresSQL 9.3+

Generating Keys

To run Concourse securely you'll need to generate 3 private keys (well, 2, plus 1 for each worker):

session_signing_key (currently must be RSA)
Used for signing user session tokens, and by the TSA to sign its own tokens in the requests it makes to the ATC.

tsa_host_key
Used for the TSA's SSH server. This is the key whose fingerprint you see when the ssh command warns you when connecting to a host it hasn't seen before.

worker_key (one per worker)
Used for authorizing worker registration. There can actually be an arbitrary number of these keys; they are just listed to authorize worker SSH access.

To generate these keys, run:

ssh-keygen -t rsa -f tsa_host_key -N ''
ssh-keygen -t rsa -f worker_key -N ''
ssh-keygen -t rsa -f session_signing_key -N ''
...and we'll also start on an authorized_keys file, currently listing this initial worker key:

cp worker_key.pub authorized_worker_keys
Starting the Web UI & Scheduler

The concourse binary embeds the ATC and TSA components, available as the web subcommand.

The ATC is the component responsible for scheduling builds, and also serves as the web UI and API.

The TSA provides a SSH interface for securely registering workers, even if they live in their own private network.

Single node, local Postgres

The following command will spin up the ATC, listening on port 8080, with some basic auth configured, and a TSA listening on port 2222.

concourse web \
  --basic-auth-username myuser \
  --basic-auth-password mypass \
  --session-signing-key session_signing_key \
  --tsa-host-key tsa_host_key \
  --tsa-authorized-keys authorized_worker_keys \
  --external-url http://my-ci.example.com
This assumes you have a local Postgres server running on the default port (5432) with an atc database, accessible by the current user. If your database lives elsewhere, just specify the --postgres-data-source flag, which is also demonstrated below.

Be sure to replace the --external-url flag with the URI you expect to use to reach your Concourse server.

In the above example we've configured basic auth for the main team. For further configuration see Configuring Auth.

Cluster with remote Postgres

The ATC can be scaled up for high availability, and they'll also roughly share their scheduling workloads, using the database to synchronize.

The TSA can also be scaled up, and requires no database as there's no state to synchronize (it just talks to the ATC).

A typical configuration with multiple ATC+TSA nodes would have them sitting behind a load balancer, forwarding port 80 to 8080, 443 to 4443 (if you've enabled TLS), and 2222 to 2222.

To run multiple web nodes, you'll need to pass the following flags:

--postgres-data-source should all refer to the same database

--peer-url should be a URL used to reach the individual ATC, from other ATCs, i.e. a URL usable within their private network

--external-url should be the URL used to reach any ATC, i.e. the URL to your load balancer

For example:

Node 0:

concourse web \
  --basic-auth-username myuser \
  --basic-auth-password mypass \
  --session-signing-key session_signing_key \
  --tsa-host-key tsa_host_key \
  --tsa-authorized-keys authorized_worker_keys \
  --postgres-data-source postgres://user:pass@10.0.32.0/concourse \
  --external-url https://ci.example.com \
  --peer-url http://10.0.16.10:8080
Node 1 (only difference is --peer-url):

concourse web \
  --basic-auth-username myuser \
  --basic-auth-password mypass \
  --session-signing-key session_signing_key \
  --tsa-host-key tsa_host_key \
  --tsa-authorized-keys authorized_worker_keys \
  --postgres-data-source postgres://user:pass@10.0.32.0/concourse \
  --external-url https://ci.example.com \
  --peer-url http://10.0.16.11:8080
Starting Workers

Workers are Garden servers, continuously heartbeating their presence to the Concourse API. Workers have a statically configured platform and a set of tags, both of which determine where steps in a Build Plan are scheduled.

Linux workers come with a set of base resource types. If you are planning to use them you need to have at least one Linux worker.

You may want a few workers, depending on the resource usage of your pipeline. There should be one per machine; running multiple on one box doesn't really make sense, as each worker runs as many containers as Concourse requests of it.

To spin up a worker and register it with your Concourse cluster running locally, run:

sudo concourse worker \
  --work-dir /opt/concourse/worker \
  --tsa-host 127.0.0.1 \
  --tsa-public-key tsa_host_key.pub \
  --tsa-worker-private-key worker_key
Note that the worker must be run as root, as it orchestrates containers.

The --work-dir flag specifies where container data should be placed; make sure it has plenty of disk space available, as it's where all the disk usage across your builds and resources will end up.

The --tsa-host refers to wherever your TSA node is listening, by default on port 2222 (pass --tsa-port if you've configured it differently). This may be an address to a load balancer if you're running multiple web nodes, or just an IP, perhaps 127.0.0.1 if you're running everything on one box.

The --tsa-public-key flag is used to ensure we're connecting to the TSA we should be connecting to, and is used like known_hosts with the ssh command. Refer to Generating Keys if you're not sure what this means.

The --tsa-worker-private-key flag specifies the key to use when authenticating to the TSA. Refer to Generating Keys if you're not sure what this means.




#!/bin/bash

set -e # exit script on error

CONCOURSE_VERSION=3.5.0

echo "Setting up 'fly' tool..."

arch=$(uname -s)
case $arch in
	Darwin)
		curl -L -O -s https://github.com/concourse/concourse/releases/download/v${CONCOURSE_VERSION}/fly_darwin_amd64
		install ./fly_darwin_amd64 /usr/local/bin/fly
		;;
	Linux)
		wget http://localhost:8080/api/v1/cli?arch=amd64&platform=linux
		;;
	*)
		echo "Unknown!"
		;;
esac


echo "Setting fly target..."
# fly --target mfr login --concourse-url http://locahost:8080


echo "Logging into docker..."

docker login -u $DOCKER_USER -p $DOCKER_PASS

mkdir -p keys/web keys/worker

ssh-keygen -t rsa -f ./keys/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/session_signing_key -N ''
ssh-keygen -t rsa -f ./keys/worker_key -N ''
cp ./keys/worker_key.pub ./keys/authorized_worker_keys







# ansible-concourse

[![Build Status](https://travis-ci.org/ahelal/ansible-concourse.svg?branch=master)](https://travis-ci.org/ahelal/ansible-concourse)

An easy way to deploy and manage a [Concourse CI](http://concourse.ci/) with a cluster of workers using ansible

## Note breaking changes as of version v3.0.0

As of version 3.0.0 of this role all options for web and worker are supported, but you need to adapt to the new config style.
Please look at [configuration section](https://github.com/ahelal/ansible-concourse#configuration).

## Requirements

* Ansible 2.0 or higher
* PostgreSQL I recommend [ansible postgresql role](https://github.com/ANXS/postgresql)

Supported platforms:

* Ubuntu 14.04/16.04
* MacOS (Early support. Accepting PRs)
* Windows (not supported yet. Accepting PRs)

Optional TLS termination

* Use concourse web argument to configure TLS (recommended)
* [ansible nginx role](https://github.com/AutomationWithAnsible/ansible-nginx)

## Overview

I am a big fan of concourse. This role will install and manage concourse.

## Examples

### Single node

```yaml
---
- name: Create Single node host
  hosts: ci.example.com
  become: True
  vars:
    concourse_web_options:
      CONCOURSE_BASIC_AUTH_USERNAME              : "myuser"
      # Set your own password and save it securely in vault
      CONCOURSE_BASIC_AUTH_PASSWORD              : "CHANGEME_DONT_USE_DEFAULT_PASSWORD"
      # Set your own password and save it securely in vault
      CONCOURSE_POSTGRES_DATABASE                : "concourse"
      CONCOURSE_POSTGRES_HOST                    : "127.0.0.1"
      CONCOURSE_POSTGRES_PASSWORD                : "conpass"
      CONCOURSE_POSTGRES_SSLMODE                 : "disable"
      CONCOURSE_POSTGRES_USER                    : "concourse"
    # ********************* Example Keys (YOU MUST OVERRIDE THEM) *********************
    # This keys are demo keys. generate your own and store them safely i.e. ansible-vault
    # Check the key section on how to auto generate keys.
    # **********************************************************************************
    concourse_key_session_public             : ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6tKH.....
    concourse_key_session_private            : |
                                                  -----BEGIN RSA PRIVATE KEY-----
                                                  MIIEowIBAAKCAQEAurSh5kbUadGuUgHqm1ct6SUrqFkH5kyJNdOjHdWxoxCzw5I9
                                                  ................................
                                                  N1EQdIhtxo4mgHXjF/8L32SqinAJb5ErNXQQwT5k9G22mZkHZY7Y
                                                  -----END RSA PRIVATE KEY-----

    concourse_key_tsa_public                  : ssh-rsa AAAAB3NzaC1yc2EAAAADAQ......
    concourse_key_tsa_private                 : |
                                                  -----BEGIN RSA PRIVATE KEY-----
                                                  MIIEogIBAAKCAQEAo3XY74qhdwY1Z8a5XnTbCjNMJu28CcEYJ1KJi1a8B143wKxM
                                                  .........
                                                  uPTcE+vQzvMV3lJo0CHTlNMo1JgHOO5UsFZ1cBxO7MZXCzChGE8=
                                                  -----END RSA PRIVATE KEY-----
    concourse_worker_keys                     :
                                  - public      : ssh-rsa AAAAB3N.....
                                    private     : |
                                                    -----BEGIN RSA PRIVATE KEY-----
                                                    MIIEpQIBAAKCAQEAylt9UCFnAkdhofItX6HQzx6r4kFeXgFu2b9+x87NUiiEr2Hi
                                                   .......
                                                    ZNJ69MjK2HDIBIpqFJ7jnp32Dp8wviHXQ5e1PJQxoaXNyubfOs1Cpa0=
                                                    -----END RSA PRIVATE KEY-----
  roles:
    - { name: "postgresql",        tags: "postgresql" }
    - { name: "ansible-concourse", tags: "concourse"  }
```

```ìni
[concourse-web]
ci.example.com
[concourse-worker]
ci.example.com
```

## Clustered nodes 2x web & 4x worker

In order to make a cluster of servers you can easily add the host to groups

```ini
[concourse-web]
ci-web01.example.com
ci-web02.example.com
[concourse-worker]
ci-worker01.example.com
ci-worker02.example.com
ci-worker03.example.com
ci-worker04.example.com
```

You would also need to generate keys for workers check [key section](https://github.com/ahelal/ansible-concourse#keys)

## Configuration

All command line options are now supported as of ansible-concourse version 3.0.0 in *Web* and *worker* as a dictionary.
**Note:** *if you are upgrade from a version prior to 3.0.0 you would need to accommodate for changes*

The configuration is split between two dictionaries *concourse_web_options* and *concourse_worker_options* all key values defined will be exported as an environmental variable to concourse process.

```yaml
concourse_web_options                        :
  CONCOURSE_BASIC_AUTH_USERNAME              : "apiuser"
  CONCOURSE_BASIC_AUTH_PASSWORD              : "CHANGEME_DONT_USE_DEFAULT_PASSWORD_AND_USEVAULT"
  CONCOURSE_POSTGRES_DATABASE                : "concourse"
  CONCOURSE_POSTGRES_HOST                    : "127.0.0.1"
  CONCOURSE_POSTGRES_PASSWORD                : "NO_PLAIN_TEXT_USE_VAUÖT"
  CONCOURSE_POSTGRES_SSLMODE                 : "disable"
  CONCOURSE_POSTGRES_USER                    : "concourse"

concourse_worker_options                     :
  CONCOURSE_GARDEN_NETWORK_POOL              : "10.254.0.0/22"
  CONCOURSE_GARDEN_MAX_CONTAINERS            : 150
```

To view all environmental options please check
[web options](web_arguments.txt) and [worker options](worker_arguments.txt).

ansible-concourse has some sane defaults defined `concourse_web_options_default` and `concourse_worker_options_default` in [default.yml](default.yml) those default will merge with `concourse_web_option` and `concourse_worker_option`. `concourse_web_option` and `concourse_worker_option`has higher precedence.


## Concourse versions

This role supports installation of release candidate and final releases. Simply overriding **concourse_version** with desired version.

* Fpr [rc](https://github.com/concourse/bin/releases/). `concourse_version : "vx.x.x-rc.xx"` that will install release candidate.
* For [final release](https://github.com/concourse/concourse/releases). ```concourse_version : "vx.x.x"```

By default this role will try to have the latest stable release look at [defaults/main.yml](https://github.com/ahelal/ansible-concourse/blob/master/defaults/main.yml#L2-L3)

## Default variables

Check [defaults/main.yml](/defaults/main.yml) for all bells and whistles.

## Keys

**Warning** the role comes with default keys. This keys are used for demo only you should generate your own and store them **safely** i.e. ansible-vault

You would need to generate 2 keys for web and one key for each worker node.
An easy way to generate your keys to use a script in ```keys/key.sh``` or you can reuse the same keys for all workers.

The bash script will ask you for the number of workers you require. It will then generate ansible compatible yaml files in ```keys/vars```
You can than copy the content in your group vars or any other method you prefer.

## Managing teams

This role supports Managing teams :

*NOTE* if you use manage _DO NOT USE DEFAULT PASSWORD_ your should set your own password and save it securely in vault. or you can look it up from web options

```yaml
concourse_manage_credential_user          : "{{ concourse_web_options['CONCOURSE_BASIC_AUTH_USERNAME'] }}"
concourse_manage_credential_password      : "{{ concourse_web_options['CONCOURSE_BASIC_AUTH_PASSWORD'] }}"
```

```yaml
    concourse_manage_teams                : True
    concourse_manage_credential_user      : "USER_TO_USE"
    concourse_manage_credential_password  : "{{ ENCRYPTED_VARIABLE }}"

    concourse_teams                 :
          - name: "team_1"
            state: "present"
            flags:
              basic-auth-username: user1
              basic-auth-password: pass1
          - name: "team_2"
            state: "absent"
          - name: "team_3"
            state: "present"
            flags:
              github-auth-client-id=XXX
              github-auth-client-secret=XXX
              github-auth-organization=ORG
              github-auth-team=ORG/TEAM
              github-auth-user=LOGIN
              github-auth-auth-url=SOMETHING
              github-auth-token-url=XX
              github-auth-api-url=XX
          - name: "team_4"
            state: "present"
            flags:
                no-really-i-dont-want-any-auth: ""
          - name: "x5"
            state: "absent"
            flags:
                basic-auth-username: user5
                basic-auth-password: pass5
```

The role supports all arguments passed to fly for more info  `fly set-team --help`.
*Please note if you delete a team you remove all the pipelines in that team*

## Auto scaling

* Scaling out: Is simple just add a new instance :)
* Scaling in: You would need to drain the worker first by running `service concourse-worker stop`

## vagrant demo

You can use vagrant to spin a test machine. ```vagrant up```

The vagrant machine will have an IP of **192.168.50.150**

You can access the web and API on port 8080 with username **myuser** and **mypass**

Once your done

```
vagrant destroy
```

## Contribution

Pull requests on GitHub are welcome on any issue.

Thanks for all the [contrubtors](https://github.com/ahelal/ansible-concourse/graphs/contributors)


## TODO

* Support pipeline upload
* Full MacOS support
* Add distributed cluster tests
* Windows support

## License

MIT
