---
title: Install Ubuntu an WSL
categories: Windows
tags: ["wsl2", "ubuntu"]
lastmod: 2025-10-23
shortname: discourseOnSwl
excerpt: Install Ubuntu 22.04 on WSL2 including backup and Git configuration for change tracking
draft: true
---

# Install Distribution and Prepare Git repository to hold our changed files

reference: https://documentation.ubuntu.com/wsl/howto/backup-and-restore/

How we configure our WSL including a GitHub repository to include changed/added files later on.

> [HINT] If you do not need a Git connection to track changes, just skip all the git steps.

## Initial installation

Our initial installation will Install the standrd WSL Ubuntu-22.04 and upgrade it to the latest
patchlevel. We will make a backup so in case we destroy everything we can restore.

First we need to add the WSL2 feature using "Turn Windows features on or off". This may require a
reboot.

Let's install our Distribution using powershell

```powershell
wsl --install "Ubuntu-22.04"
```

Enter your username and password when prompted. Which will directly bring you into the system.

Next is to bring the Distro to the most recent patchlevel which needs _root_ permission.

```bash
sudo apt update
sudo apt upgrade -y
exit
```

which will bring us back to our powershell

## Backup (optional)

We will do our initial backup. which allows for fast recovery.

Make sure the instance is stopped. We are paranoid and completely terminate the WSL

```powershell
wsl --shutdown
wsl
>   NAME            STATE           VERSION
> * Ubuntu-22.04    Stopped         2

# create a backup folder
mkdir c:\_wsl\
# and backup using a step identifier and current date
wsl --export "Ubuntu-22.04" c:\_wsl\00-Ubuntu-22.04.05-20251027.tar
```

## Restore (optional)

Each backup can be imported as a new Instance by changing the name

```powershell
wsl --import "Ubuntu-Import" c:\_wsl c:\_wsl\00-Ubuntu-22.04.05-20251026.tar
```

to replace an existing system you will have to remove that first

```powershell
wsl -terminate "Ubuntu-22.04"
wsl --unregister "Ubuntu-22.04"
wsl --import "Ubuntu-22.04" c:\_wsl c:\_wsl\00-Ubuntu-22.04.05-20251027.tar
```

# Configure Git

To have a more fine grained history we use Git to track changes. Each backup would take up about
1.5GB.

## Configure Git

Taking a Full backup after every change and restoring things is quite an effort. I like to be able
to track smaller changes so we just turn our WSL installation into a git repository which has a nice
history and allows us to go back based on commits.

We also set up the repository as special so it takes the initial installation as baseline and only
changed/added files will show up for being staged.

Most of our changes will be done in protected files, so we need to become _root_ for **every** git
operation.

I'm lazy so I will use a root shell started using `sudo -s`

```bash
sudo -s
cd /
git init
git branch -M main
```

add username and email to have proper commit author using `git config --global --edit`

In my case I will track that one in GitHub, so I give my registered GitHub username and email.

```ini
[user]
name = USERNAME
email = YOUR@EMAIL
```

and that should be printed as

```bash
> git config --global --list
user.name=USERNAME
user.email=YOUR@EMAIL
```

### Adjusting .gitignore

Unfornutely git does have a functionalitzy like a baseline to start from, so all files will be shown
as untracked. committing them will store 2GB in the repo. Without much hacking I decided to ignore
everything and manually add the stuff I change.

so here's my starter `/.gitignore`

```text
# ignore all
/*
```

The good one is, now all files that I have committed will be tracked and shown as usual. The 2GB are
never added. The bad thing: If a file has not yet bin committed it won't show up as modified. To
overcome this, I use `git add -f <file>` every time I change a new file.

## Install SHH Keys for GitHub (optional)

reference:
https://stackoverflow.com/questions/76052045/how-to-save-the-login-credentials-for-github-on-linux

I also want to push to github, so I create my ssh setup. Remember we excluded that from our commits.
So back up at a safe place.

Log on to your WSL instance and open a root shell using `sudo -s`

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
> Generating public/private ALGORITHM key pair.
> Enter a file in which to save the key (/home/YOU/.ssh/id_ALGORITHM):[Press enter]
> Enter passphrase (empty for no passphrase): [Type a passphrase]
> Enter same passphrase again: [Type passphrase again]
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

> [INFO] we never add that to the repo and might destroy the machine, so backup the keys to a safe
> place.

## Configure GitHub

Create a new SSH key in your GitHub account and import the **public** key from
`~/.ssh/id_ed25519.pub`

From now on you can access your github account using `git@github.com:USERNAME/REPO.git`

Use the UI to create a repository to hold changes to the wsl instance. Lets name it _wsl-config_.
You might want to use a private one for that.

## Initial Repository Setup

> [WARNING!] make sure if you add /root, that /root/.ssh is **not** added as staged. We do not want
> our secret in a remote repo!

We now create our initial baseline by committing the current fileset and mark them as unchanged. Be
patient, each of these steps may take a while.

```bash
sudo -s
git commit -m "repo(config) : Set initial baseline"
git remote add origin git@github.com:USER/wsl-config.git
git push --set-upstream origin main
# accept the certificate from GitHub
```

If all went fine, your GitHub repository now contains a `.gitignore`.

Ready to Rumble.

> [INFO] remember to use `git add -f` if you change a file

# Configure wsl

We like a proper hostname and have some mount config.

-  change WSL settings `/etc/wsl.conf` (linux wsl)

   ```
   [boot]
   systemd=true

   [network]
   hostname=discourse
   ```

-  change `c:\users\rik\.wslconfig` (windows host)

   discourse needs some memory and complains (default is 4GB) -> 8GB seems to work

   ```
   [wsl2]
   memory = 8GB
   processors = 4
   ```

Reboot the WSL Linux machine

# Install discourse

reference:
https://meta.discourse.org/t/guide-to-setting-up-discourse-development-environment-windows-11/282227

A simple online will install our Discourse development environment

```bash
bash <(wget -qO- https://raw.githubusercontent.com/discourse/install-rails/master/linux)
```

Be patient. This will download and build Discozrse from scratch including all of it's components.

-  Start Postgres SQL

   ```bash
   > sudo service postgresql start
   # and verify
   >sudo systemctl status postgresql
   postgresql.service - PostgreSQL RDBMS
       Loaded: loaded (/lib/systemd/system/postgresql.service; enabled; vendor preset: enabled)
       Active: active (exited) since Fri 2025-10-31 18:14:50 CET; 8min ago
     Main PID: 3646 (code=exited, status=0/SUCCESS)
           CPU: 1ms

   Oct 31 18:14:50 discourse systemd[1]: Starting PostgreSQL RDBMS...
   Oct 31 18:14:50 discourse systemd[1]: Finished PostgreSQL RDBMS.
   ```

-  block memory complains (from the reference)

   ```
   sudo sysctl vm.overcommit_memory=1
   ```

-  start Redis server

   ```
   > redis-server --daemonize yes
   # and verify
   > ps -ef | grep redis
   redis       9600       1  0 18:16 ?        00:00:01 /usr/local/bin/redis-server 127.0.0.1:6379
   ```

-  install discourse

   ```
   > source ~/.bashrc
   ```

   Now we have to change some things compared to the guide . npm and node are update and dependency
   hells. luckily at the bottom or the post there are some comments that give some hints

   -  _Ubuntu_ came with _Ruby_ 3.2 but the installation package required 3.3. No problem just
      install this and that and you can go _Ruby_ also locally for the _Discourse_ build and not
      system wide. We use _rbenv for that, which is already installed. Luckily it lists \_Ruby
      3.3.10_. Also be patient here, it's build from scratch.

   ```
   > cd ~
   > rbenv install 3.3.10
   ==> Installing ruby-3.3.10...
   -> ./configure "--prefix=$HOME/.rbenv/versions/3.3.10" --enable-shared --with-ext=openssl,psych,+
   -> make -j 4
   -> make install
   ==> Installed ruby-3.3.10 to /home/rik/.rbenv/versions/3.3.10
   ```

   -  activate 3.3.10 for our project
      > cd discourse rbenv versions
   -  3.2.1 (set by /home/rik/.rbenv/version) 3.3.10
      > echo "3.3.10" > .ruby-version rbenv versions 3.2.1 (set by /home/rik/.rbenv/version)
   -  3.3.10

   ```

   * Node, too has the wrong verion (18) we need 20. No problem just install this and that and you can go.

   > curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
   # exit and reenter shell
   > nvm list-remote | grep "Latest LTS" -> v20.19.5
   > nvm install v20.19.5
   Downloading and installing node v20.19.5...
   Downloading https://nodejs.org/dist/v20.19.5/node-v20.19.5-linux-x64.tar.xz...
   ############################################# 100.0%
   Computing checksum with sha256sum
   Checksums matched!
   Now using node v20.19.5 (npm v10.8.2)
   Creating default alias: default -> v20.19.5
   ```

   -  and last use _pnpm_ instead of ~Yarn~

   ```bash
   > pnpm install
   ```

   -  the comment solved all my problems til now, so I blindly followed the guidanc on _pgvector_

   ```
   > cd /tmp
   > git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git
   > cd pgvector
   > make
   > sudo make install
   cd ~/discourse
   ```

-  Create an admin account

   That one is missing in the documentation. but solvable use a valid email.

   ```
   rake admin:create
   ```

-  Start Discourse

   Don't try a hostname here, unless you have a full featured DNS running. It's a dev instance

   ```
   > DISCOURSE_HOSTNAME=localhost UNICORN_LISTENER=localhost:3000 bin/ember-cli -u
   ```

# add Highlight.js plugin

reference:
https://meta.discourse.org/t/install-a-new-language-for-highlight-js-via-a-theme-component/292480

```
const beancountLang = function(e){var c="[A-Z][A-Za-z0-9-]*",a="[0-9]{4}[-|/][0-9]{2}[-|/][0-9]{2}",b="(balance|commodity|custom|document|event|note|open|pad|price|query)",t={cN:"literal",b:/([\-|\+]?)([\d]+[\.]?[\d]*)/,r:0},n={cN:"string",b:'"',e:'"',r:0,c:[e.BE]},s={cN:"name",b:"\\{",e:"\\}",c:[{cN:"literal",b:a},t,n,{cN:"subst",b:"[A-Z][A-Z0-9'._-]{0,22}[A-Z0-9]"}]};return{aliases:["beancount","bean","ledger"],c:[{cN:"built_in",b:"^(include|option|plugin|popmeta|poptag|pushmeta|pushtag)",r:0},{b:"^"+a+"\\s+"+b,rB:!0,r:10,c:[{cN:"type",b:a,e:/\s+/,eE:!0},{cN:"keyword",b:b}]},{b:"^"+a+"\\s+.\\s",rB:!0,r:10,c:[{cN:"type",b:a,e:"\\s+",eE:!0},{cN:"variable",b:".",endsParent:!0}]},e.C(";","$"),{cN:"meta",b:/^\s{2,}[a-z][A-Za-z0-9\-_]+:/},s,{cN:"name",b:"@"},{cN:"type",b:c+":",r:0,c:[{cN:"subst",b:c+"(:"+c+")?"}]},{cN:"section",b:/^\*\s+?.*/},{cN:"link",b:/\^[A-Za-z0-9\-_\/.]+/},{cN:["emphasis"],b:/#[A-Za-z0-9\-_\/.]+/},n,t]}}
api.registerHighlightJSLanguage("beancount", beancountLang);
```

```
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {

/*! `hugo` grammar compiled for Highlight.js 11.11.1 */
const hugoLang = function(xml) { return function(e){
var t=/\{\{- |\{\{(?!-)/,s=/ -\}\}|(?<! -)\}\}/,a={variants:[{
begin:[/\./,/\w+/],beginScope:{1:"property",2:"title.function.invoke"}},{
begin:[/\w+/],beginScope:{1:"title.function.invoke"}}],contains:[{
scope:"property",match:/(\.\w+)+/}]},i={
begin:/\b(transform.HighlightCodeBlock|resources.ExecuteAsTemplate|strings.ContainsNonSpace|transform.HTMLToMarkdown|lang.FormatNumberCustom|collections.Complement|collections.Dictionary|collections.NewScratch|partials.IncludeCached|strings.FindRESubmatch|transform.CanHighlight|transform.HTMLUnescape|transform.PortableText|collections.Intersect|encoding.Base64Decode|encoding.Base64Encode|lang.FormatAccounting|resources.Fingerprint|resources.PostProcess|transform.Markdownify|resources.FromString|transform.HTMLEscape|collections.Delimit|collections.KeyVals|collections.Querify|collections.Reverse|collections.Shuffle|collections.SymDiff|compare.Conditional|hugo.IsMultilingual|images.ColorBalance|images.GaussianBlur|inflect.Singularize|lang.FormatCurrency|resources.GetRemote|strings.ContainsAny|strings.SliceString|transform.Highlight|transform.Remarshal|transform.Unmarshal|transform.XMLEscape|collections.Append|hugo.IsDevelopment|images.UnsharpMask|lang.FormatPercent|openapi3.Unmarshal|resources.GetMatch|strings.CountRunes|strings.CountWords|strings.FirstUpper|strings.TrimPrefix|strings.TrimSuffix|time.ParseDuration|transform.Plainify|collections.After|collections.Apply|collections.First|collections.Group|collections.Index|collections.IsSet|collections.Merge|collections.Slice|collections.Union|collections.Where|hugo.IsProduction|images.AutoOrient|images.Brightness|images.Saturation|inflect.Pluralize|lang.FormatNumber|resources.PostCSS|strings.HasPrefix|strings.HasSuffix|strings.ReplaceRE|strings.RuneCount|strings.TrimRight|strings.TrimSpace|templates.Current|transform.Emojify|collections.Last|collections.Sort|collections.Uniq|encoding.Jsonify|hugo.Environment|hugo.IsMultihost|images.Grayscale|inflect.Humanize|partials.Include|resources.ByType|resources.Concat|resources.Minify|strings.Contains|strings.TrimLeft|strings.Truncate|templates.Exists|transform.ToMath|collections.Seq|compare.Default|css.TailwindCSS|hugo.CommitHash|hugo.IsExtended|hugo.WorkingDir|images.Colorize|images.Contrast|images.Pixelate|reflect.IsSlice|resources.Babel|resources.Match|resources.ToCSS|strings.Replace|strings.ToLower|strings.ToUpper|templates.Defer|urls.AbsLangURL|urls.RelLangURL|collections.In|hugo.BuildDate|hugo.Generator|hugo.GoVersion|images.Opacity|images.Overlay|images.Padding|images.Process|images.Sigmoid|lang.Translate|math.ToDegrees|math.ToRadians|resources.Copy|strings.FindRE|strings.Repeat|strings.Substr|urls.Anchorize|cast.ToString|collections.D|crypto.FNV32a|crypto.SHA256|diagrams.Goat|hugo.IsServer|images.Config|images.Dither|images.Filter|images.Invert|math.MaxInt64|os.FileExists|path.BaseName|reflect.IsMap|resources.Get|safe.HTMLAttr|strings.Chomp|strings.Count|strings.Split|strings.Title|time.Duration|urls.JoinPath|cast.ToFloat|data.GetJSON|fmt.Erroridf|hugo.Version|images.Gamma|images.Sepia|math.Counter|math.ModBool|math.Product|strings.Diff|strings.Trim|crypto.HMAC|crypto.SHA1|css.PostCSS|data.GetCSV|debug.Timer|fmt.Println|fmt.Warnidf|hash.FNV32a|hash.XxHash|images.Mask|images.Text|os.ReadFile|time.AsTime|time.Format|urls.AbsURL|urls.RelRef|urls.RelURL|urls.URLize|cast.ToInt|compare.Eq|compare.Ge|compare.Gt|compare.Le|compare.Lt|compare.Ne|crypto.MD5|debug.Dump|fmt.Errorf|fmt.Printf|hugo.Store|images.Hue|lang.Merge|math.Atan2|math.Floor|math.Round|os.ReadDir|path.Clean|path.Split|safe.JSStr|urls.Parse|fmt.Print|fmt.Warnf|hugo.Deps|images.QR|math.Acos|math.Asin|math.Atan|math.Ceil|math.Rand|math.Sqrt|os.Getenv|path.Base|path.Join|safe.HTML|css.Sass|js.Babel|js.Batch|js.Build|math.Abs|math.Add|math.Cos|math.Div|math.Log|math.Max|math.Min|math.Mod|math.Mul|math.Pow|math.Sin|math.Sub|math.Sum|math.Tan|path.Dir|path.Ext|safe.CSS|safe.URL|time.Now|urls.Ref|math.Pi|os.Stat|safe.JS|time.In)\b/,
keywords:{$pattern:/\w+\.\w+/,
built_in:["transform.HighlightCodeBlock","resources.ExecuteAsTemplate","strings.ContainsNonSpace","transform.HTMLToMarkdown","lang.FormatNumberCustom","collections.Complement","collections.Dictionary","collections.NewScratch","partials.IncludeCached","strings.FindRESubmatch","transform.CanHighlight","transform.HTMLUnescape","transform.PortableText","collections.Intersect","encoding.Base64Decode","encoding.Base64Encode","lang.FormatAccounting","resources.Fingerprint","resources.PostProcess","transform.Markdownify","resources.FromString","transform.HTMLEscape","collections.Delimit","collections.KeyVals","collections.Querify","collections.Reverse","collections.Shuffle","collections.SymDiff","compare.Conditional","hugo.IsMultilingual|10","images.ColorBalance","images.GaussianBlur","inflect.Singularize","lang.FormatCurrency","resources.GetRemote","strings.ContainsAny","strings.SliceString","transform.Highlight","transform.Remarshal","transform.Unmarshal","transform.XMLEscape","collections.Append","hugo.IsDevelopment|10","images.UnsharpMask","lang.FormatPercent","openapi3.Unmarshal","resources.GetMatch","strings.CountRunes","strings.CountWords","strings.FirstUpper","strings.TrimPrefix","strings.TrimSuffix","time.ParseDuration","transform.Plainify","collections.After","collections.Apply","collections.First","collections.Group","collections.Index","collections.IsSet","collections.Merge","collections.Slice","collections.Union","collections.Where","hugo.IsProduction|10","images.AutoOrient","images.Brightness","images.Saturation","inflect.Pluralize","lang.FormatNumber","resources.PostCSS","strings.HasPrefix","strings.HasSuffix","strings.ReplaceRE","strings.RuneCount","strings.TrimRight","strings.TrimSpace","templates.Current","transform.Emojify","collections.Last","collections.Sort","collections.Uniq","encoding.Jsonify","hugo.Environment|10","hugo.IsMultihost|10","images.Grayscale","inflect.Humanize","partials.Include","resources.ByType","resources.Concat","resources.Minify","strings.Contains","strings.TrimLeft","strings.Truncate","templates.Exists","transform.ToMath","collections.Seq","compare.Default","css.TailwindCSS","hugo.CommitHash|10","hugo.IsExtended|10","hugo.WorkingDir|10","images.Colorize","images.Contrast","images.Pixelate","reflect.IsSlice","resources.Babel","resources.Match","resources.ToCSS","strings.Replace","strings.ToLower","strings.ToUpper","templates.Defer","urls.AbsLangURL","urls.RelLangURL","collections.In","hugo.BuildDate|10","hugo.Generator|10","hugo.GoVersion|10","images.Opacity","images.Overlay","images.Padding","images.Process","images.Sigmoid","lang.Translate","math.ToDegrees","math.ToRadians","resources.Copy","strings.FindRE","strings.Repeat","strings.Substr","urls.Anchorize","cast.ToString","collections.D","crypto.FNV32a","crypto.SHA256","diagrams.Goat","hugo.IsServer|10","images.Config","images.Dither","images.Filter","images.Invert","math.MaxInt64","os.FileExists","path.BaseName","reflect.IsMap","resources.Get","safe.HTMLAttr","strings.Chomp","strings.Count","strings.Split","strings.Title","time.Duration","urls.JoinPath","cast.ToFloat","data.GetJSON","fmt.Erroridf","hugo.Version|10","images.Gamma","images.Sepia","math.Counter","math.ModBool","math.Product","strings.Diff","strings.Trim","crypto.HMAC","crypto.SHA1","css.PostCSS","data.GetCSV","debug.Timer","fmt.Println","fmt.Warnidf","hash.FNV32a","hash.XxHash","images.Mask","images.Text","os.ReadFile","time.AsTime","time.Format","urls.AbsURL","urls.RelRef","urls.RelURL","urls.URLize","cast.ToInt","compare.Eq","compare.Ge","compare.Gt","compare.Le","compare.Lt","compare.Ne","crypto.MD5","debug.Dump","fmt.Errorf","fmt.Printf","hugo.Store|10","images.Hue","lang.Merge","math.Atan2","math.Floor","math.Round","os.ReadDir","path.Clean","path.Split","safe.JSStr","urls.Parse","fmt.Print","fmt.Warnf","hugo.Deps|10","images.QR","math.Acos","math.Asin","math.Atan","math.Ceil","math.Rand","math.Sqrt","os.Getenv","path.Base","path.Join","safe.HTML","css.Sass","js.Babel","js.Batch","js.Build","math.Abs","math.Add","math.Cos","math.Div","math.Log","math.Max","math.Min","math.Mod","math.Mul","math.Pow","math.Sin","math.Sub","math.Sum","math.Tan","path.Dir","path.Ext","safe.CSS","safe.URL","time.Now","urls.Ref","math.Pi","os.Stat","safe.JS","time.In"]
},contains:[a]},r={begin:[/\.(?=\w+)/],beginScope:{1:"template-variable.context"
},contains:[a]},o={variants:[{begin:/\w+(?=\.)/,contains:[a]},{match:/\w+/}],
keywords:{$pattern:/\w+/,
built_in:["findRESubmatch","partialCached","base64Decode","base64Encode","htmlUnescape","safeHTMLAttr","fingerprint","markdownify","singularize","absLangURL","complement","countrunes","countwords","dateFormat","fileExists","htmlEscape","newScratch","relLangURL","anchorize","hasPrefix","hasSuffix","highlight","intersect","pluralize","replaceRE","safeJSStr","unmarshal","duration","erroridf","humanize","plainify","readFile","safeHTML","slicestr","truncate","default","delimit","emojify","getJSON","jsonify","keyVals","modBool","partial","postCSS","println","querify","readDir","replace","safeCSS","safeURL","shuffle","symdiff","warnidf","absURL","append","errorf","findRE","getCSV","getenv","minify","printf","relref","relURL","safeJS","sha256","string","substr","urlize","xxhash","after","apply","babel","chomp","first","float","group","index","isset","lower","merge","print","slice","split","title","toCSS","union","upper","warnf","where","cond","dict","hmac","i18n","last","page","sha1","site","sort","time","trim","uniq","add","div","int","md5","mod","mul","now","pow","ref","seq","sub","eq","ge","gt","in","le","lt","ne","T"],
literal:["false","true","nil"]}},n={variants:[{begin:[/\$\w+(?=\.)/],
beginScope:{1:"template-variable"},contains:[a]},{match:/\$\w+/,
scope:"template-variable"}]},l={begin:[/\(/],beginScope:{1:"punctuation"},
end:[/\)/],endScope:{1:"punctuation"}
},c=[e.NUMBER_MODE,e.QUOTE_STRING_MODE,e.APOS_STRING_MODE,{scope:"string.raw",
match:/`[^`]*`/,keywords:[]},i,o,r,n,{scope:"operator",match:/[|,=]|:=/},{
scope:"template-variable.context",match:/\.|\$/},l],
vc = [
  e.COMMENT(/\s*(\{\{- \/\*|\{\{\/\*)/,/\*\/ -\}\}|\*\/\}\}/,{
relevance:10}),{begin:/\{\{(#|>|!--|!)/,end:/\}\}/,illegal:/.*/},{
begin:[t,/\s*/,/break|continue|else|end/],beginScope:{1:"template-tag",
3:"keyword"},end:[s],endScope:{1:"template-tag"}},{
begin:[t,/\s*/,/block|define|else\swith|else\s+if|range|return|template|try|with|if/],
beginScope:{1:"template-tag",3:"keyword"},end:[s],endScope:{1:"template-tag"},
contains:c},{begin:[t],beginScope:{1:"template-tag"},end:[s],endScope:{
1:"template-tag"},contains:c}],
vl = {
  case_insensitive:!1,
  contains: vc
};
if (xml) { vl.subLanguage = ["xml"] };
return l.contains=c,vl;

}};

api.registerHighlightJSLanguage("hugo", hugoLang(1));
api.registerHighlightJSLanguage("hugo-html", hugoLang(1));
api.registerHighlightJSLanguage("hugo-text", hugoLang(0));

});
```
