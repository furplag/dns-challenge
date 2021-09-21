# DNS Challenge
scripts to facilitate the creation of wildcard SSL certificates with [mod_md](https://github.com/icing/mod_md#mdchallengedns01) .

## TL;DR
* [x] enable to use "DNS-01" challenge with mod_md .
* [x] enable to use wildcard into sub domains .
* [x] enable to auto renew with certbot and systemd timer .

> Note:  
> this scripts enables only to using with Cloudflare DNS, yet .
## Why Cloudflare ?
he gave me a useful free plan, that's all, and that's enough .

## Installation
1. download them all , and put it somewhere .
>  ensure the scripts readable, and executable ( at least that dns-challenge.sh is executable ) by web server user ( e.g. apache, www-data ) .
```bash
# instruction
dns-challenge/
├── certbot-authenticator.sh ... use --manual-auth-hook in certbot
├── certbot-cleanup.sh       ... use --manual-cleanup-hook in certbot
├── cloudflare
│   ├── configurator.sh      ... process for initialization
│   ├── setup.sh             ... a script add DNS record for ACME token validation
│   └── teardown.sh          ... a script to remove DNS record (s) by name
├── .credencials
│   └── cloudflare           ... configuration file
└── dns-challenge.sh         ... main executable
```

1. setting up .credencials/{a type of DNS} file
```bash
# 0 is true in a toggle .
[cloudflare]

[auth]
# choose at least one from A and B .
# use API token access, even if both parameter specified .

# A. API Token ( recommends )
# an access token of Cloudflare which can edit DNS records .
cloudflare_dns_api_token=

# B. global access token ( deprecated )
# means access as the master of the zone .
cloudflare_dns_auth_email=
cloudflare_dns_auth_key=

[dns]
# API endpoint ( optional, default: https://api.cloudflare.com/client/v4/zones ) .
base_url=

# a prefix of TXT record name ( optional, default: _acme-challenge ) .
record_prefix=

# DNS zone id ( optional ignore this if DNS zone name specified ) .
zone_id=

# DNS zone name ( optional ) .
zone=

# TTL ( seconds ) of TXT recoed ( optional, default: 120 ) .
# Note: numeric only (60 - 2147483647), or "1" ( means "auto" ) .
ttl=

# waiting seconds for DNS propagation ( optional, default: 10 ) .
propagation_seconds=

# DNS record deletion check strictly, if false ( optional, default: 0 ) .
teardown_lazily=

[development]
# a toggle for logging ( optional, default: 1 ) .
logging=

# absolute path to log directory ( must be writable, optional, default: (path to dns-challange.sh directory)/logs ) .
log_dir=

# name of log file ( optional, default: script name ) .
log=

# absolute path to log directory ( must be writable, optional, default: (path to dns-challange.sh directory)/logs ) .
log_dir=

# no stdout, if false ( optional, default: 1 ) .
log_console=

# mute debug log, if false ( optional, default: 1 ) .
debug=

```

1. create symlink named as "dns-challenge-{a type of DNS}" `to dns-challenge.sh`, using under mod_md .
```bash
ln -s {path to dns-challenge directory}/dns-challenge.sh dns-challenge-{a type of DNS}
```

1. create symlink named as "dns-challenge-{a type of DNS}" `to dns-challenge.sh`, using under certbot .
> use [Certbot DNS plugins](https://certbot.eff.org/docs/using.html#dns-plugins) should better, if supported .
```bash
ln -s {path to dns-challenge directory}/certbot-authenticator.sh certbot-authenticator-{a type of DNS}
ln -s {path to dns-challenge directory}/certbot-cleanup.sh certbot-cleanup-{a type of DNS}
```

```bash
# for example, using Cloudflare DNS API .
dns-challenge/
├── certbot-authenticator-cloudflare -> ./certbot-authenticator.sh
├── certbot-authenticator.sh
├── certbot-cleanup-cloudflare -> ./certbot-cleanup.sh
├── certbot-cleanup.sh
├── cloudflare
│   ├── configurator.sh
│   ├── setup.sh
│   └── teardown.sh
├── .credencials
│   └── cloudflare
├── dns-challenge-cloudflare -> ./dns-challenge.sh
├── dns-challenge.sh
└── logs/
```

1. configure apache for mod_md .
```httpd.ssl.conf
<IfModule ssl_module>
  <IfModule md_module>
    MDCAChallenges dns-01
	  MDChallengeDns01 {path to dns-challenge directory}/dns-challenge-{a type of DNS}
	  MDCertificateAgreement accepted
	  <MDomain any.domain.you.controls>
		  MDMember *.any.domain.you.controls
	  </MDomain>
  </IfModule>

  <VirtualHost *:443>
    ServerNane sub.any.domain.you.controls
    ServerAlias any.domain.you.controls
    ServerAdmin {valid Email}
    ...
  </VirtualHost>
  ...
</IfModule>
```

## How it works
when mod_md needs a challenge, it will run the command
  `dns-challenge-{a type of DNS} setup [domain] [validation token]`.

when the challenge is complete and no longer necessary, mod_md will run
`dns-challenge-{a type of DNS} teardown [domain]`.

## License
[Apache-2.0 License](/LICENSE)

## Trademark Notice
Cloudflare is a registered trademark of Cloudflare, Inc.
