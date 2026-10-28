---
title: Install Discourse on WSL2
categories: Windows
tags: ["wsl2", "discourse"]
lastmod: 2025-10-23
shortname: discourseOnSwl
excerpt: Install Docker based Discourse on WSL
draft: true
---

# Installing Discourse

Discourse is extremely picky with email security. Seems it uses all the modern features like SPF and
DKIM which require a proper DNS and Domain setup.

On the other hand WSL is configured for easy integration with the Hosts Filesystem and Services...

The basic Setup using Docker works just fine but to be able to do anything you need to get a MAIL
for local registration. So we additionally need to tweak our WSL instance to provide a proper
DNS/SMTP configuration. At last to the extend Discourse requires.

-  change WSL settings `/etc/wsl.conf`

stop automatically generating these files

```ini
[boot]
systemd=true

[network]
hostname=server
generateHosts=false
generateResolvConf=false
```

-  change `c:\users\rik\.wslconfig`

   discourse needs some memory and complains if set to 5GB in WSL -> 8GB seems to work

   ```
   [wsl2]
   memory = 8GB
   processors = 4
   ```

-  adjust `/etc/hosts`

   ```
   127.0.0.1       localhost
   127.0.1.1       server  wsl.fritz.box

   # The following lines are desirable for IPv6 capable hosts
   ::1     ip6-localhost ip6-loopback
   fe00::0 ip6-localnet
   ff00::0 ip6-mcastprefix
   ff02::1 ip6-allnodes
   ff02::2 ip6-allrouters
   ```

-  static setting for Windows right now using `C:\Windows\System32\drivers\etc/hosts`

   ```
   172.17.222.191 mail.wsl.fritz.box
   172.17.222.191 ns.wsl.fritz.box
   172.17.222.191 discourse.wsl.fritz.box
   ```

### MAIL

This will setup a local _catch-all_ mail server. This is **not** suited to handle the outside world!

https://mikesmithers.wordpress.com/2025/05/06/setting-up-a-local-only-smtp-server-in-ubuntu/

We skip the mail client section (we have no UI) and are fine with console based mailing
`/usr/bin/mail`

### Summary 1

At this step we have

-  send mails from the WSL to any user on WSL. all mails are sent to a fixed username
-  WSL can be accessed by IP or FQHN from Windows host
-  name resolution of WSL server on the WSL itself IP<->NAME

## BIND

Let's try to setup a full featured DNS we will need for MX records, SPF and DKIM

https://dev.to/teetoflame/setting-up-a-dns-server-on-my-local-system-bind9-1a8c

-  `apt install bind9 bind9utils bind9-doc -y`

It's always a good idea to check configuration after a change. These commands may help based on the
config done

```bash
# configuration
named-checkconf
named-checkzone wsl.fritz.box /etc/bind/db.wsl
named-checkzone 222.17.172.in-addr.arpa /etc/bind/db.172
# restart
sudo systemctl restart bind9

# tests
nslookup IP | HOSTNAME | FQHN

dig @localhost wsl.fritz.box
dig @localhost server.wsl.fritz.box
dig @localhost mail.wsl.fritz.box
dig -x 172.17.222.191
```

### configure local subdomain

We now will change our nameservice config to use our local bind service for name resolution:

-  passing all unknown stuff to
   -  WSL default
   -  The home network DNS -> which then asks ISP
-  be authoritative for the subdomain wsl.fritz.box
-  reverse resolution for 172.17 (ESL subnet)
-  add mail server records

-  `/etc/bind/named.conf.options`

   ```
   options {
           directory "/var/cache/bind";

           // If there is a firewall between you and nameservers you want
           // to talk to, you may need to fix the firewall to allow multiple
           // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

           // If your ISP provided one or more IP addresses for stable
           // nameservers, you probably want to use them as forwarders.
           // Uncomment the following block, and insert the addresses replacing
           // the all-0's placeholder.
           recursion yes;
           forwarders {
                   10.255.255.254;
                   192.168.69.1;
           };

           //========================================================================
           // If BIND logs error messages about the root key being expired,
           // you will need to update your keys.  See https://www.isc.org/bind-keys
           //========================================================================
           dnssec-validation auto;
           auth-nxdomain no;

           listen-on-v6 { any; };
           allow-query { any; };
   };
   ```

-  `/etc/bin/named.conf.local

   ```
   //
   // Do any local configuration here
   //

   // Consider adding the 1918 zones here, if they are not used in your
   // organization
   //include "/etc/bind/zones.rfc1918";

   zone "wsl.fritz.box" {
     type master;
     file "/etc/bind/db.wsl";
   };

   zone "0.17.172.in-addr.arpa" {
     type master;
     file "/etc/bind/db.172";
   };
   ```

-  `/etc/bin/db.wsl`

   ```
   ;
   ; BIND data file for wsl.fritz.box
   ;
   $TTL    604800
   @       IN      SOA     ns.wsl.fritz.box. root.wsl.fritz.box. (
                             2023111801 ; Serial
                             604800     ; Refresh
                             86400      ; Retry
                             2419200    ; Expire
                             604800 )   ; Negative Cache TTL

             IN      NS      ns.wsl.fritz.box.
   ns        IN      A       172.17.222.191
   @         IN      A       172.17.222.191
   discourse IN      A       172.17.222.191
   mail      IN      A       172.17.222.191
   @         IN      MX 10   mail.wsl.fritz.box.
   ```

-  `/etc/bin/db.172`

   ```
   ;
   ; Reverse DNS file for 172.17.222.0/24
   ;
   $TTL    604800
   @       IN      SOA     ns.wsl.fritz.box. root.wsl.fritz.box. (
                             2023111801 ; Serial
                             604800     ; Refresh
                             86400      ; Retry
                             2419200    ; Expire
                             604800 )   ; Negative Cache TTL

           IN      NS      ns.wsl.fritz.box.
   191     IN      PTR     wsl.fritz.box.
   ```

-  `/etc/resolv.conf`

   ```
   nameserver 172.17.222.191
   search wsl.fritz.box
   ```

## add SPF Record

background: https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf format bind9:
https://webhostinggeeks.com/howto/how-to-add-spf-record-in-bind-dns-zone-on-linux/

-  we add this at the end of `/etc/bin/db.wsl`

   ```
   wsl.fritz.box.    IN      TXT     "v=spf1 mx ~all"
   ```

-  restart bind `systemctl restart bind9`

### test the record

```bash
> dig wsl.fritz.box txt
...
;; ANSWER SECTION:
wsl.fritz.box.          604800  IN      TXT     "v=spf1 mx ~all"
...
;; SERVER: 172.17.222.191#53(172.17.222.191) (UDP)
```

We do not need our MTA to really verify anything, so we skip that part.

## add DKIM record

all details here: https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf

-  Install `apt install opendkim opendkim-tools -y`
-  add postfix user to dkim group: `gpasswd -a postfix opendkim`
-  adapt `/etc/opendkim.conf`

   ```
   # This is a basic configuration for signing and verifying. It can easily be
   # adapted to suit a basic installation. See opendkim.conf(5) and
   # /usr/share/doc/opendkim/examples/opendkim.conf.sample for complete
   # documentation of available configuration parameters.

   Syslog                  yes
   SyslogSuccess           yes
   LogWhy                  yes

   # Common signing and verification parameters. In Debian, the "From" header is
   # oversigned, because it is often the identity key used by reputation systems
   # and thus somewhat security sensitive.
   Canonicalization        relaxed/simple
   #Mode                   sv
   #SubDomains             no
   AutoRestart             yes
   AutoRestartRate         10/1M
   Background              yes
   DNSTimeout              5
   SignatureAlgorithm      rsa-sha256
   OversignHeaders         From

   # Signing domain, selector, and key (required). For example, perform signing
   # for domain "example.com" with selector "2020" (2020._domainkey.example.com),
   # using the private key stored in /etc/dkimkeys/example.private. More granular
   # setup options can be found in /usr/share/doc/opendkim/README.opendkim.
   #Domain                 example.com
   #Selector               2020
   #KeyFile                /etc/dkimkeys/example.private

   # In Debian, opendkim runs as user "opendkim". A umask of 007 is required when
   # using a local socket with MTAs that access the socket as a non-privileged
   # user (for example, Postfix). You may need to add user "postfix" to group
   # "opendkim" in that case.
   UserID                  opendkim
   UMask                   007

   # Socket for the MTA connection (required). If the MTA is inside a chroot jail,
   # it must be ensured that the socket is accessible. In Debian, Postfix runs in
   # a chroot in /var/spool/postfix, therefore a Unix socket would have to be
   # configured as shown on the last line below.
   Socket                  local:/run/opendkim/opendkim.sock
   #Socket                 inet:8891@localhost
   #Socket                 inet:8891
   #Socket                 local:/var/spool/postfix/opendkim/opendkim.sock

   PidFile                 /run/opendkim/opendkim.pid

   # Hosts for which to sign rather than verify, default is 127.0.0.1. See the
   # OPERATION section of opendkim(8) for more information.
   #InternalHosts          192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12

   # The trust anchor enables DNSSEC. In Debian, the trust anchor file is provided
   # by the package dns-root-data.
   TrustAnchorFile         /usr/share/dns/root.key
   Nameservers             172.17.222.191
   # Map domains in From addresses to keys used to sign messages
   KeyTable           refile:/etc/opendkim/key.table
   SigningTable       refile:/etc/opendkim/signing.table

   # Hosts to ignore when verifying signatures
   ExternalIgnoreList  /etc/opendkim/trusted.hosts

   # A set of internal hosts whose mail should be signed
   InternalHosts       /etc/opendkim/trusted.hosts
   ```

-  create folder structure

   ```bash
   mkdir -p /etc/opendkim/keys/wsl.fritz.box
   chown -R opendkim:opendkim /etc/opendkim
   chmod go-rw /etc/opendkim/keys
   ```

-  create `/etc/opendkim/signing.table`

   ```
   *@wsl.fritz.box    default._domainkey.wsl.fritz.box
   *@*.wsl.fritz.box    default._domainkey.wsl.fritz.box
   ```

-  create `/etc/opendkim/key.table`

   ```
   default._domainkey.wsl.fritz.box     wsl.fritz.box:default:/etc/opendkim/keys/wsl.fritz.box/default.private
   ```

-  `/etc/opendkim/trusted.hosts`

   ```
   127.0.0.1
   localhost

   .wsl.fritz.box
   ```

-  generate keys

   ```bash
   opendkim-genkey -b 2048 -d wsl.fritz.box -D /etc/opendkim/keys/wsl.fritz.box -s default -v
   ```

-  adjust permissions

   ```
   chown opendkim:opendkim /etc/opendkim/keys/wsl.fritz.box/default.private
   sudo chmod 600 /etc/opendkim/keys/wsl.fritz.box/default.private
   ```

-  add the public key to bind config

   The public key already has bind compatible format, so we just append it to our zone.

   ```bash
   cat /etc/opendkim/keys/wsl.fritz.box/default.txt >> /etc/named/db.wsl
   ```

   which results in our final file:

   ```
   ;
   ; BIND data file for wsl.fritz.box
   ;
   $TTL    604800
   @       IN      SOA     ns.wsl.fritz.box. root.wsl.fritz.box. (
                           2023111805 ; Serial
                           604800     ; Refresh
                           86400      ; Retry
                           2419200    ; Expire
                           604800 )   ; Negative Cache TTL

             IN      NS      ns.wsl.fritz.box.
   ns        IN      A       172.17.222.191
   @         IN      A       172.17.222.191
   discourse IN      A       172.17.222.191
   mail      IN      A       172.17.222.191
   @         IN      MX  10  mail.wsl.fritz.box.

   wsl.fritz.box.    IN      TXT     "v=spf1 mx ~all"

   default._domainkey      IN      TXT     ( "v=DKIM1; h=sha256; k=rsa; "
           "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnoJerR8fhYcs1/kLIYvBCthoXpmfrsjRFXypzykY/pLqinUZsMQWNiqjqxliT/7d1E45T9BodbqOk8+Mvi9vzOMqGnYIfUw8SFy9ry0Obme64+BlvHHKE7wMzTD4MiIRgobGgx4rLJ/s2aBvRhZDIQVxlIpXfjPS+hUoxuhfZRTi1mEtYcOYuHKWTU+j3bG1V44eIKALOjBcM5"
           "iof4e5uACY2twJrcyEGyJhrwCQ0eHeopTSL4/EQsu4lP/HbTbdc3Cm5UmpT1s3clF3cQyQgu6sYx3p8YdJDwEa5oKJDFpBqVsuTR1CVyLv+9ruDI7so7eMGEsccLsse4C6FSe4lwIDAQAB" )  ; ----- DKIM key default for wsl.fritz.box
   ```

### Test the record

```bash
> dig +short default._domainkey.wsl.fritz.box TXT
"v=DKIM1; h=sha256; k=rsa; " "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnoJerR8fhYcs1/kLIYvBCthoXpmfrsjRFXypzykY/pLqinUZsMQWNiqjqxliT/7d1E45T9BodbqOk8+Mvi9vzOMqGnYIfUw8SFy9ry0Obme64+BlvHHKE7wMzTD4MiIRgobGgx4rLJ/s2aBvRhZDIQVxlIpXfjPS+hUoxuhfZRTi1mEtYcOYuHKWTU+j3bG1V44eIKALOjBcM5" "iof4e5uACY2twJrcyEGyJhrwCQ0eHeopTSL4/EQsu4lP/HbTbdc3Cm5UmpT1s3clF3cQyQgu6sYx3p8YdJDwEa5oKJDFpBqVsuTR1CVyLv+9ruDI7so7eMGEsccLsse4C6FSe4lwIDAQAB"

> opendkim-testkey -vvv -d wsl.fritz.box -s default
opendkim-testkey: using default configfile /etc/opendkim.conf
opendkim-testkey: checking key 'default._domainkey.wsl.fritz.box'
opendkim-testkey: key not secure
opendkim-testkey: key OK
```

Check out the reference document for details about the _unsecure key_ message.

## Install discourse

reference: https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md

Now that we have the proper setup, we can start following the Discourse installation guide.

-  Section 1-4 are already addressed by the previous steps.
-  Section 5 is automagically handled with the Discourse

Let's start with section 6 and follow

-  `yes`to the Docker installation
-  `ignore` Docker Desktop recommendation

And here are the answers to the next questions based on the configuration already done

```
Hostname for your Discourse? [discourse.example.com]: discourse.wsl.fritz.box

Email address for admin account(s)? [me@example.com,you@example.com]: rik@wsl.fritz.box
SMTP server address? [smtp.example.com]: mail.wsl.fritz.box
SMTP port? [587]: 25
SMTP user name? [user@example.com]: rik@wsl.fritz.box
SMTP password? []: JustAPassword
notification email address? [noreply@discourse.wsl.fritz.box]: rik@wsl.fritz.box
Optional email address for Let's Encrypt warnings? (ENTER to skip) [me@example.com]: <ENTER>
Optional MaxMind Account ID (ENTER to continue without MAXMIND GeoLite2 geolocation database) [123456]: <ENTER>
```

Get a coffee while discourse is installing.

Result is:

```
app was not started !
./discourse-doctor may help diagnose the problem.

Found 4GB of memory and 8 physical CPU cores
setting db_shared_buffers = 1024MB
setting UNICORN_WORKERS = 8
containers/app.yml memory parameters updated.
```

-  so I manually edited `containers/app.yml` and set a dummy password
-  `./discourse-doctor`and see what happens ...seems to build from scratch... and after a while:
   ```
   Discourse container app is now running.
   . . . waiting 30 seconds for container to crank up. . .
   ```
   mail test fails - port 25 refused

## expose port 80 to windows host

https://www.ipserverone.info/knowledge-base/how-to-open-ports-in-iptables/

-  destrying Discourse

   ```
   cd  /var/discourse
   ./launcher stop app
   ./launcher destroy app
   cd /var
   rm -rf discourse
   ```

## dev install windows

## Uninstalling WSL

source https://itsfoss.com/uninstall-wsl/

To remove everything use

-  `wsl --list`to get all installed Instances
-  `wsl --unregister NAME` for each of them
-  `wsl --list -v` to check that there are no distributions

-  Delete the distributions using "Add remove programs"
-  remove WSL using "Turn Windows features on or off"

## Install Ubuntu

-  `wsl --install "Ubuntu-22.04"`
-  enter your user account name and a password

DONE.

## Changing configurations

https://github.com/MicrosoftDocs/wsl/blob/main/WSL/wsl-config.md

Linux system: `/etc/wsl.conf` Windows system: `c:\Users\rik\.wslconfig`

-  after changing settings, make sure you stopped all instances of the touched distro
-  test with `wsl --list --running
-  close one: wsl --terminate DISTRO
-  close all: wsl shutdown

## purge docker

sudo docker ps -aq | xargs -r sudo docker rm -f sudo docker image prune -a -f sudo docker volume
prune -f sudo docker network prune -f sudo systemctl disable --now docker docker.socket containerd
|| true sudo apt update sudo apt purge -y \
 docker-ce docker-ce-cli containerd.io \
 docker-buildx-plugin docker-compose-plugin \
 docker-ce-rootless-extras || true sudo apt purge -y docker.io docker-doc podman-docker containerd
runc || true

sudo apt autoremove -y sudo apt clean sudo rm -rf /var/lib/docker /var/lib/containerd sudo rm -rf
/etc/docker /etc/containerd 2>/dev/null || true sudo rm -rf /etc/systemd/system/docker.service.d
2>/dev/null || true sudo rm -f /var/run/docker.sock sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg sudo apt update rm -rf ~/.docker

systemctl --user stop docker 2>/dev/null || true systemctl --user disable docker 2>/dev/null || true
systemctl --user daemon-reload || true command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1 && \
 dockerd-rootless-setuptool.sh uninstall || true rm -rf ~/.local/share/docker ~/.config/docker rm -f
~/.config/systemd/user/docker.service sudo loginctl disable-linger "$USER" 2>/dev/null || true

### Verification

if command -v docker; then echo "Docker still present"; else echo "Docker CLI not found ✔"; fi dpkg
-l | grep -E "^(ii|rc)\s+(docker|containerd)" || echo "No docker/containerd packages found ✔"
systemctl status docker 2>/dev/null | grep -q running && echo "docker running" || echo "docker not
running ✔" systemctl status containerd 2>/dev/null | grep -q running && echo "containerd running"
|| echo "containerd not running ✔"
