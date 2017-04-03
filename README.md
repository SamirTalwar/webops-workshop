# Web Ops

At lightning speed, this workshop will cover the bits that aren’t code that make up a working web app. These include servers, monitoring, deployment mechanisms, logging, alerting, secret management, recovery mechanisms… you get the idea.

It's not clear how far we'll get in two hours but material will be provided afterwards so you can finish anything off on your own.

You'll work in pairs on a virtual machine (which will be provided a few days beforehand so you have time to set it up).

Topics include:

  * how to set up a web server on Linux,
  * deploying changes to a web server with minimum downtime,
  * keeping an eye on your server to make sure things are working,
  * tracking down production bugs,
  * managing persistent data (such as your database),
  * secure communication over HTTPS,
  * and, if we have time, how to do all this in the buzzword of the decade, containers.

---

## Prerequisites

1. An SSH client.
    1. If you're on macOS or Linux, you have one built in.
    2. On Windows 10, you can install [Bash on Windows][Bash on Windows Installation Guide].
    3. On any other version of Windows, download and install [PuTTY][].
2. An SSH key. You may have one already. If so, skip this.
    1. If you're running on macOS, Linux, or Bash on Windows, it will be located at *~/.ssh/id_rsa* or *~/.ssh/id_dsa*. If not, just run `ssh-keygen`.
    2. If you're using PuTTY, run *puttygen.exe*.
3. A fresh [Ubuntu Server 16.04.2 LTS][Download Ubuntu Server] virtual machine. This will be distributed beforehand, but you can skip to step 4 if you want to create one yourself, or make one on The Cloud™ if you know what you're doing.
    1. Import the *.ova* file into [VirtualBox][].
    2. Once it's imported, click "Network" and change the network from "NAT" to "Bridged Adapter".
    3. Remember that the username is "webops" and the password is "let me in please".
    4. You're done. Skip to step 5.
4. If you didn't import a VM, you can make one yourself too as follows:
    1. Start downloading the ISO.
    2. Create a new [VirtualBox][] VM named "WebOps Workshop".
    3. Pick *Linux*, then *Ubuntu (64-bit)* as the operating system.
    4. Give it 2048 MB of RAM.
    5. Allow it to create a hard disk, with all the defaults.
    6. Once it's created, click "Storage" and assign the ISO to the optical drive.
    7. Hop over to the "Network" tab and change the network from "NAT" to "Bridged Adapter".
    8. Start the VM.
    9. Install Ubuntu. If the setting is not mentioned below, go with the default.
        1. Pick an appropriate language, keyboard layout, time zone, etc.
        2. Set the hostname to "webops-workshop".
        3. Set the username to "webops", and pick a password you'll remember easily.
        4. Choose to install security updates automatically.
    10. Reboot.
    11. Log in.
    12. Update (`sudo apt update`) and upgrade (`sudo apt upgrade`).
    13. Install OpenSSH (`sudo apt install openssh-server`).
    14. Reboot to ensure everything's working, then shut down the VM.
5. An SSH connection to the VM.
    1. Start the VM.
    2. Get the VM's IP address (`ip address`).
    3. Copy the SSH key to the server VM:
       ```sh
       cat ~/.ssh/id_rsa.pub | ssh webops@<VM IP> 'mkdir -p ~/.ssh && cat > ~/.ssh/authorized_keys'
       ```
    4. SSH in with `ssh webops@<VM IP>`. You shouldn't need your password.
    5. Shut the VM down and take a snapshot.

[Bash on Windows Installation Guide]: https://msdn.microsoft.com/en-us/commandline/wsl/install_guide
[PuTTY]: http://www.chiark.greenend.org.uk/~sgtatham/putty/
[Download Ubuntu Server]: https://www.ubuntu.com/download/server
[VirtualBox]: https://www.virtualbox.org/

## Playbook

### Preparation

Create an AWS server with Ubuntu 16.04 (Xenial), and save the PEM as *~/.ssh/\<something\>.pem* with a chmod of 600.

In the security group, open TCP ports 80, 443 and 8080, and UDP ports 60000-61000 (for Mosh).

Create a hostname for it.

Set up your SSH configuration by adding the following to *~/.ssh/config*:

```
Host <hostname>
    User ubuntu
    IdentityFile <path to PEM file>
```

And set up your Ansible configuration by creating *ansible/inventory*:

```
<hostname> ansible_user=ubuntu ansible_ssh_private_key_file=<path to PEM file>
```

Assuming we're using the [Predestination][] app, you'll need the following too:

```sh
ansible-playbook ansible/prerequisites.yaml
```

[Predestination]: https://github.com/SamirTalwar/predestination

### 00:00 — Introduction

A short introduction to deploying and running a website.

### 00:10 — Make sure everyone has a machine working

Hopefully not many people will have had trouble installing a VM and setting up SSH keys. In any case, pair them up, so only half of them need to.

In case everyone has had issues, take 10 minutes to sort them all out.

### 00:20 — Start a web app on the server

Pick an app that takes `PORT` as an environment variable.

[Here's one I wrote][Predestination], in case you're stuck. If you use it:

```sh
sudo add-apt-repository ppa:jonathonf/python-3.6
sudo apt update
sudo apt upgrade
sudo apt install make python3.6 virtualenv
make site-packages
# run `./web` to start it
```

If you're not using Predestination, change `./web` to however you start your application.

Then run it:

```sh
PORT=8080 ./web # or however you start the application
```

*[Browse to the URL and show it off. If possible, leave the browser window open. It will automatically reconnect if you terminate the server and restart it.]*

Note that we're using the port 8080. HTTP usually runs over port 80, but we can't start an application there without it running as *root*, and we don't want to do that, as an attacker compromising the web server could get access to anything else.

In fact, we probably want to make sure the application has as few rights as possible. So let's create a user just for that.

```sh
sudo useradd web
sudo --user=web PORT=8080 ./web
```

*[Leave it running for a few seconds, then kill it again.]*

### 00:30 — Keep it running

Now, we can run the web server, but it's running in our terminal. We can't do anything else.

So run it in the background.

```sh
sudo --user=web PORT=8080 ./web &
```

… Sort of works. It's still tied to this TTY (terminal), and its output is interfering with our work. We can redirect it to a file:

```sh
sudo --user=web PORT=8080 ./web >>& /var/log/site.log &
```

If we lose SSH connection, the site might go down.

*[Show it off, then run `fg`, then Ctrl+C.]*

You can use `nohup` to disconnect the process from the terminal.

```sh
nohup sudo --user=web PORT=8080 ./web >>& /var/log/site.log &
```

This isn't great, though. What if we want to stop the application? We have to write down the PID? And remember to kill it? We can't just start a new version over the top—it won't even start, because the port is taken.

On Linux, services are often managed through scripts living in */etc/init.d* or */etc/rc.d*. *[Show one of them.]* This works, but is a massive pain. It's a lot of complicated script and it's really easy to get it wrong.

Instead, we're going to use [Supervisor][], a process control system that's way easier to manage. Supervisor will take care of running our process, even if we restart the computer.

So let's configure it to run our application.

*[Copy the following file to /etc/supervisor/conf.d/site.conf:]*

```
[program:site]
command=/home/ubuntu/site/web
environment=PORT=8080
user=web
```

Now we just tell `supervisorctl`, the control program, to reload its configuration.

```sh
sudo supervisorctl
> restart
> status
```

And it's running in the background. Lovely.

[Supervisor]: http://supervisord.org/

### 00:40 — We're still on port 8080

[iptables][iptables How To] to the rescue. We don't want to run our site as the root user, so we'll use iptables, a firewall and network routing service that comes preinstalled on basically every Linux box, to route traffic from port 80 to port 8080.

It's as simple as this:

```sh
sudo iptables --table=nat --append=PREROUTING --proto=tcp --dport=80 --jump=REDIRECT --to-port=8080
```

You can check it's there with `sudo iptables --table=nat --list`. We should now be able to talk to our site without specifying a port.

*[Delete the port from the URL.]*

iptables isn't persistent. However, we can install the *iptables-persistent* package to automatically load rules from a file on startup. Then all we need to do is run the following each time we change them:

```sh
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
```

(We have to run the whole thing in a subshell because otherwise we can't redirect to that file; it's owned by *root*.)

And while we're at it, let's use a real hostname instead.

*[Cut to the preset DNS settings, then show the site at the real hostname.]*

[iptables How To]: https://help.ubuntu.com/community/IptablesHowTo

### 00:45 — Can you imagine doing all this a second time?

Now imagine this server breaks because, I don't know, we misconfigure iptables and disable SSH. It's in The Cloud™ so we have no access to the actual terminal. What we can do, though, is delete it and try again.

Can you imagine doing that a second time? Ugh. Our website will be down for ages.

Instead, we're going to use an infrastructure automation tool. My favourite is [Ansible][], which is what we're going to use today, but there are plenty of others. The most popular are [Puppet][], [Chef][] and [SaltStack][].

In this repository you'll find an Ansible "playbook" that will configure a server just as we have. All you need to do is point it at the server you've already set up.

```sh
export ANSIBLE_INVENTORY=$PWD/ansible/inventory
ansible all -m ping
```

Ansible works over SSH, so there's nothing to do on the server. You just need it installed on the client, along with an *inventory* file.

*[Show the inventory file.]*

Now let's get Ansible to configure our server. First we'll set up all the boring prerequisites—Make, Python, etc.

*[Show ansible/prerequisites.yaml.]*

```sh
ansible-playbook ansible/prerequisites.yaml
```

Now we'll set up the application:

```sh
ansible-playbook ansible/predestination.yaml
```

Voila. Nothing changed (except the application going down for a few seconds). That's because we mostly did all the work already. You'll note that the supervisor was, however, reconfigured—that's because the application was moved from */home/ubuntu/predestination* to */var/www/predestination*.

Using Ansible (or whatever else), we can easily throw away this server and set up a new one in just a few clicks.

[Ansible]: https://www.ansible.com/
[Chef]: https://www.chef.io/chef/
[Puppet]: https://puppet.com/
[SaltStack]: https://saltstack.com/

### 01:00 — Now it's time to release a new version.

Let's make it blue.

*[Change it to blue. Can't be that hard. Try `#147086`.]*

All we need to do is make a couple of changes to the Ansible playbook. We'll add the following lines to the "clone" section:

```
        version: blue
        update: yes
```

*[Ship it, wait 30 seconds and reload.]*

Nice and easy. Ansible took care of figuring out what's changed and what's stayed the same. It updates the Git repository to point at our new version, then instructs the supervisor to restart it. It's only down for a few seconds while it restarts.

If you really can't go down, even for a second, there are more advanced techniques you can use. For example, you can use *blue-green deployment*. What this means is that we have two servers (codenamed "blue" and "green"). Only one of the servers is active at any time (this means that we somehow configured a third server, the "gateway", to redirect all traffic to this one). Let's assume it's the blue one. When we release, we release to the inactive (green) server, ensure that everything is healthy, then activate it. If it doesn't work, figure out why, and meanwhile, the blue server is still happily serving requests.

It's quite common to automate this kind of deployment either periodically or every time a commit gets pushed to the *master* branch. THe latter is called *continuous deployment*. This is related to *continuous integration*. The idea is that each time you push, a server runs your Ansible playbook or other deployment mechanism for you. You could manage this server yourself, but you could also use [Travis CI][], [CircleCI][], [Shippable][] or another online service, which are often free to start.

[CircleCI]: https://circleci.com/
[Shippable]: https://www.shippable.com/
[Travis CI]: https://travis-ci.org/

### 01:10 — I compile my code, and it's private!

Right now, we're shipping Python and JavaScript, which we can just run from the source code. However, some language platforms require the source code to be *compiled* first. If this is the case, it's not enough to just clone the repository—you have to create a *release* and store it somewhere. If you use GitHub or Bitbucket, you'll find that there's a mechanism there for uploading releases, which you can then instruct Ansible to download.

You might also want to keep your code private. This is doable but requires that you configure Ansible to generate an SSH key, tell your host what it is, then use that to clone the repository or download the releases.

You could get Ansible to just copy the release from your local machine, but this means that you'll never be able to go back to an older release, as it'll get overwritten each time. For this reason, I wouldn't recommend it.

All of this is beyond the scope of this tutorial, but ask me more about it if you're curious.

### 01:15 — What if it goes down?

That'd be awful, right?

Fortunately, the Internet will let me know. I've configured [Pingdom][] to tell me if the site goes down. It'll send me an email within five minutes if it doesn't come back up sharpish.

*[Show the emails that have inevitably been sent in the last hour.]*

There are lots of tools just like Pingdom. Find the one you like. I recommend starting on a free trial to make sure it's right for you.

### 01:20 — What if it breaks?

It'd be nice to know what's going on on the server, especially if things are screwy. This is what logging is for.

Let's say, for example, that I introduce a bug into our application.

*[Introduce a bug. There's one on the `error-prone` branch if you're stuck for ideas.]*

So, let's say I introduce a bug that stops the game. This is bad, right? How do I trace it?

Well, your application logs are your friends. It's better if you actively put "log" statements in your application to tell you what's going on, but even if you don't, catastrophic errors will probably still be logged.

Using `supervisorctl`, we can ask the supervisor daemon for the logs like this:

```sh
supervisorctl tail -f predestination stderr
```

(There's two output streams: STDOUT and STDERR. Logs usually go on STDERR, but you might want to check both, or configure the supervisor to merge them.)

In this output stream, we can see what's called a "stack trace". This allows us to trace the error to the very line that's causing the problem.

*[Show the line.]*

Once we diagnose the problem, we can now fix the bug and redeploy, or roll back to a previous version.

### 01:30 — How do I store data?

Short answer: don't. At least not on your machine.

Remember how we've been using third-party services such as Pingdom, CircleCI and Amazon Web Services to manage parts of our stack? Let's introduce one more. Whatever your database, someone else is better at managing it than you. There are lots of free or cheap options, such as [ElephantSQL][], which provides PostgreSQL, a powerful relational database, [Compose][], which provides hosted versions of MongoDB, Redis, and other document-based databases, [Amazon RDS][], which provides a few different relational databases, and many more.

You might think it's easy or cheaper to run your own. And it may well be, until you accidentally delete some data or your hard drive breaks. At that point, you'll wish you paid for someone else to manage backups and redundancy.

And whatever you do, don't store data text files on the server. It's the easiest way to accidentally lose data.

[ElephantSQL]: https://www.elephantsql.com/
[Compose]: https://compose.com/
[Amazon RDS]: https://aws.amazon.com/rds/

### 01:35 — So what's all this Docker business?

Right. Here come the fireworks.

[Docker][] is a useful way of packaging up an application to handle all this stuff for you. All you need is the Docker daemon on the server and you can run an application really easily. It can be instructed to re-run the application if it crashes, just like supervisord, and can be set up with Ansible or another deployment tool. It also ships with one of its own, called [Docker Compose][].

Docker also packages everything. This means that you don't need to install anything on the server except Docker itself, as the *Docker image* that you build contains all the application dependencies. This includes Python (or whatever you want to use to make your web app).

*[Launch the Docker image from ansible/predestination-docker.yaml.]*

It's been around for a few years, so many don't consider it quite as stable as running on bare Linux, but personally, I think the convenience of packaging an entire application up locally is so good that I'm willing to make that trade-off. We no longer need to configure files on the server; we just instruct Docker to start a "container" from our image and away we go. It also means we can test our images locally and they'll work almost entirely the same, whether we're on Windows, macOS or Linux.

Building Docker images is beyond the scope of this tutorial, but I encourage you to have a go with it.

[Docker]: https://docs.docker.com/
[Docker Compose]: https://docs.docker.com/compose/
