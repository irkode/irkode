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

> [NOTE] NOT FOR PRODUCTION USE we do all that stuff quite bare and unsecured. It's target is
> playing with Discourse settings and configuration.
>
> It's in **NO** way ready to serve a Discourse Forum.
>
> **Never** expose that machine to the outside world.

## Settings

wsl username: rik wsl password: rik wsl hostname: server wsl domain: wsl.home wsl default dns
server: 10.255.255.254 windows dns server: 192.168.69.1 wsl subnet: 172.17.222.191/24

## Commonly use packages

```bash
sudo apt install telnet -y
```

## Install WSL and prepare machine

-  Search for "Turn Windows features on or off" and check WSL
-  create/edit `c:\users\rik\.wslconfig`

   ```
   [wsl2]
   memory = 8GB
   processors = 4
   ```

-  open a powershell
   ```powershell
   wsl install Ubuntu-22.04
   ```
-  enter username and password when prompted

Now we are in a bash shell on our fresh WSL Ubuntu instance

-  (optional) turn of the login message

   ```bash
   touch /home/rik/.hushlogin
   ```

-  always good to have the latest patches, so check for update and apply

   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

-  reboot and relogin

## Configure DNS resolution

reference: https://dev.to/teetoflame/setting-up-a-dns-server-on-my-local-system-bind9-1a8c

We now will change our nameservice config to use our local bind service for name resolution:

-  passing all unknown stuff to
   -  WSL default
   -  The home network DNS -> which then asks ISP
-  be authoritative for the domain wsl.home
-  reverse resolution for 172.17 (ESL subnet)
-  add mail server records

We will use Bind9 as our DNS server.

```bash
sudo apt install bind9 bind9utils bind9-doc -y
```

### configure forwarding `/etc/bind/named.conf.options`

> [HINT] replace
>
> -  "192.168.69.1" with the DNS you use on your windows host
> -  "10.255.255.254" with the nameserver listed in `/etc/resolv.conf`

```{highlight-lines="12,15"}
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

### add the zones where we feel responsible `/etc/bin/named.conf.local`

we do not follow the hint, as we use two of these RFC zones

```
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";

zone "wsl.home" {
  type master;
  file "/etc/bind/db.wsl";
};

zone "222.17.172.in-addr.arpa" {
  type master;
  file "/etc/bind/db.172";
};
```

### Forward DNS : Name -> IP `/etc/named/db.wsl.home`

We directly add our SPF record needed by Discourse.

```
$TTL    604800
@       IN      SOA     ns.wsl.home. root.wsl.home. (
                          1          ; Serial
                          604800     ; Refresh
                          86400      ; Retry
                          2419200    ; Expire
                          604800 )   ; Negative Cache TTL

          IN      NS      ns1.wsl.home.
ns1       IN      A       172.17.222.191 ; name server
@         IN      A       172.17.222.191 ; localhost
discourse IN      A       172.17.222.191 ; discourse instance
server    IN      A       172.17.222.191 ; generic name

mail      IN      A       172.17.222.191 ; mail server
@         IN      MX 10   mail.wsl.home.

; configure trusted senders (Discourse requirement)
wsl.home  IN      TXT     "v=spf1 mx ~all"
```

### Reverse DNS : IP -> Name `/etc/named/db.172`

```
;
; Reverse DNS file for 172.17.222.0/24
;
$TTL    604800
@       IN      SOA     ns1.wsl.home. root.wsl.home. (
                          1          ; Serial
                          604800     ; Refresh
                          86400      ; Retry
                          2419200    ; Expire
                          604800 )   ; Negative Cache TTL

        IN      NS      ns1.wsl.home.
191     IN      PTR     server.wsl.home.
```

### check our settings

always good to check simple typos

```
named-checkconf
named-checkzone wsl.home ./db.wsl.home
named-checkzone 222.17.172.in-addr.arpa ./db.172
```

The default WSL configuration automatically creates `/etc/resolv.conf` when started. We have to turn
that off and add our fixed one

```
[network]
hostname=server
generateResolvConf=false
```

That one needs a full WSL restart.

-  shutdown the machine `shutdown now`

-  in powershell `wsl --shutdown` (will affect all instances!)

-  and back to a fresh root shell on the WSL

### change Nameserver `/etc/resolv.conf`

now the WSL does not touch that file. In fact it is not there anymore:

```bash
echo "nameserver 172.17.222.191" > /etc/resolv.conf
echo "search wsl.home" >> /etc/resolv.conf
```

### Final tests

With forward, reverse lookup and our SPF record

```
nslookup
> server
Default server: 172.17.222.191
Address: 172.17.222.191#53
> localhost
Server:         172.17.222.191
Address:        172.17.222.191#53

Name:   localhost
Address: 127.0.0.1
Name:   localhost
Address: ::1
> mail
Server:         172.17.222.191
Address:        172.17.222.191#53

Name:   mail.wsl.home
Address: 172.17.222.191
> discourse.wsl.home
Server:         172.17.222.191
Address:        172.17.222.191#53

Name:   discourse.wsl.home
Address: 172.17.222.191
> 172.17.222.191
191.222.17.172.in-addr.arpa     name = server.wsl.home.
> exit
```

let's check our SPF record

```
dig +short wsl.home. txt
"v=spf1 mx ~all"
```

```
[network]
hostname=server
generateResolvConf=false
```

## Install Mail Server

We set that up here to be minimal. The Target is to receive and send mails from our Discourse
instance to local users only.

Let's install our packages:

```bash
sudo apt-get install postfix -y
sudo apt install mailutils -y
```

This will start the configuration process right away.

-  Server type: `Local`
-  Mail name: `wsl.home`

This will allow for local mailing. But some come from outside (Docker containers). So we need to
adjust things here, too.

> [INFO] Don't forget to restart postfix if you change some configs later. Some changes need a
> restart
>
> ```bash
> sudo systemctl reload postfix
> sudo systemctl restart postfix
> ```

## Configure Firewall rules

Our mail port is 25 and we need to send from a Docker container. We will open up that completely

```bash
sudo ufw allow 25/tcp
```

### liston on the network, too `/etc/postfix/main.cf`

```
inet_interfaces = all
mynetworks = 127.0.0.1/8, 172.17.222.191/24
```

You should now be able to send mails from any local user to any local user

```bash
echo "test email to" | sendmail rik@wsl.home
cat /var/mail/USERNAME
```

## add our DKIM record (OpenDKIM)

reference: https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf

This will need create some keys and additional configs. Lets go.

Let's install our packages:

```bash
sudo apt install opendkim opendkim-tools -y
```

```bash
sudo systemctl restart bind9
```

restart the daemon using `systemctl restart bind9`
