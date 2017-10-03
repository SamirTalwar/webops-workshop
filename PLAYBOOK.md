# Playbook

I'm using `$` to denote commands to be run on your local machine, and `%` to denote commands to be run on the server.

Instructions for the presenter that require leaving the terminal are in *[italicised brackets]*.

## 00:00 — Pair everyone up and create their instances

Hopefully this is just a matter of changing the `count` variable and re-running `terraform apply`.

## 00:05 — Introduction

A short introduction to deploying and running a website.

## 00:10 — Distribute connection details

Give everyone an IP address/EC2 hostname and the same SSH key. (I know, but we're all friends here.) Get them to put the SSH key in *~/.ssh/webops* and add the following to their *~/.ssh/config*:

```
Host webops
    HostName <hostname>
    User ubuntu
    IdentityFile ~/.ssh/webops
```

Hopefully not many will have trouble SSHing in.

In case everyone has had issues, take 10 minutes to sort them all out.

## 00:20 — Start a web app on the server

Pick a web application that takes `PORT` as an environment variable. This tutorial will assume you're using an app I wrote called [Predestination][].  If you pick a different application, change `./web` to however you start it.

Log in to the server. (I'm using `mosh` here, but you can use `ssh` if you prefer it or you don't have a choice (i.e. you're on Windows).)

```sh
$ mosh webops
```

Clone the repository and install its dependencies:

```sh
% git clone https://github.com/SamirTalwar/predestination.git
% cd predestination
% make site-packages
```

Then run it:

```sh
% PORT=8080 ./web # or however you start the application
```

*[Browse to the URL and show it off. If possible, leave the browser window open. It *may* automatically reconnect if you terminate the server and restart it, but I wouldn't bank on it.]*

Note that we're using the port 8080. HTTP usually runs over port 80, but we can't start an application there without it running as *root*, and we don't want to do that, as an attacker compromising the web server could get access to anything else.

In fact, we probably want to make sure the application has as few rights as possible. So let's create a user just for that.

```sh
% sudo useradd web
% sudo --user=web PORT=8080 ./web
```

*[Leave it running for a few seconds, then kill it again.]*

[Predestination]: https://github.com/SamirTalwar/predestination

## 00:30 — Keep it running

Now, we can run the web server, but it's running in our terminal. We can't do anything else.

So run it in the background.

```sh
% sudo --user=web PORT=8080 ./web &
```

… Sort of works. It's still tied to this TTY (terminal), and its output is interfering with our work. We can redirect it to a file:

```sh
% sudo --user=web PORT=8080 ./web >>& /var/log/site.log &
```

If we lose SSH connection, the site might go down.

*[Show it off, then run `fg`, then Ctrl+C.]*

You can use `nohup` to disconnect the process from the terminal.

```sh
% nohup sudo --user=web PORT=8080 ./web >>& /var/log/site.log &
```

This isn't great, though. What if we want to stop the application? We have to write down the PID? And remember to kill it? We can't just start a new version over the top—it won't even start, because the port is taken.

On Linux, services are often managed through scripts living in */etc/init.d* or */etc/rc.d*. *[Show one of them.]* This works, but is a massive pain. It's a lot of complicated scripts and it's really easy to get it wrong.

Instead, we're going to use [Supervisor][], a process control system that's way easier to manage. Supervisor will take care of running our process, even if we restart the computer.

So let's configure it to run our application.

*[Copy the following file to /etc/supervisor/conf.d/site.conf:]*

```
[program:site]
command=/home/ubuntu/predestination/web
environment=PORT=8080
user=web
```

Now we just tell `supervisorctl`, the control program, to reload its configuration.

```sh
% sudo supervisorctl
> reread
> update
> status
... wait 10 seconds
> status
> exit
```

And it's running in the background. Lovely.

This is a big advancement: we've gone from running commands to defining a configuration. The former is *imperative*: we know our current state and our desired state, and we invoke a sequence of commands to get there. The latter is *declarative*: we don't know our current state, just our desired state, and the computer figures out the sequence of operations. This is much easier to reason about, and therefore less error-prone, allowing your sysadmin to use their memory for far more useful things.

[Supervisor]: http://supervisord.org/

## 00:40 — We're still on port 8080

[nginx][] to the rescue. We don't want to run our site as the root user, so we'll use nginx, an HTTP server, to route traffic from port 80 to port 8080.

Delete */etc/nginx/sites-enabled/default* to disable the default endpoint.

Next, create a file called */etc/nginx/sites-available/predestination.conf*:

```
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;

  location / {
    proxy_pass http://localhost:8080;
  }
}
```

You'll need to enable it by creating a symbolic link in the *sites-enabled* directory:

```sh
% sudo ln -s /etc/nginx/sites-available/predestination.conf /etc/nginx/sites-enabled/
```

Next, reload nginx:

```sh
% sudo nginx -s reload
```

We should now be able to talk to our site without specifying a port.

*[Delete the port from the URL and make sure it works.]*

You might find that while the game loads, it doesn't run. If that's the case, it's probably because WebSockets aren't proxying correctly (sorry about that). You can force the application to use HTTP polling rather than Websockets by adding the `TRANSPORTS=polling` environment variable to the supervisor file and reloading the application with `supervisorctl reread`, then `supervisorctl update`.

[nginx]: https://nginx.org/

Great job. Your site is up. Now disconnect from the server with *Ctrl+D* or `exit`.

## 00:45 — Can you imagine doing all this a second time?

Now imagine this server breaks because, I don't know, we misconfigure the server and disable SSH. It's in The Cloud™ so we have no access to the actual terminal. What we can do, though, is delete it and try again.

Can you imagine doing that a second time? Ugh. Our website will be down for ages.

Instead, we're going to use an infrastructure automation tool. My favourite is [Ansible][], which is what we're going to use today, but there are plenty of others. The most popular are [Puppet][], [Chef][] and [SaltStack][].

Ansible works over SSH, so there's nothing to do on the server. You just need it installed on the client, along with an *inventory* file. Let's create one now called *ansible/inventory*:

```
[aws]
<your server IP address> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/webops
```

If you're on Windows, you can't run Ansible, but don't worry. SSH into your server, install Ansible (`sudo apt install ansible`), clone this repository and create an *ansible/inventory* file as follows:

```
[local]
localhost ansible_connection=local
```

Now, let's try it.

```sh
$ export ANSIBLE_INVENTORY=$PWD/ansible/inventory
$ ansible all -m ping
```

That pings all the servers to ensure they're responding over SSH.

Now we'll set up the application:

```sh
ansible-playbook ansible/predestination.yaml
```

Voila. Not much happened (except the application going down for a few seconds). Take a look at the *ansible/predestination.yaml* file, and note the things that changed:

1. The application was re-cloned, because this time we're cloning into a new directory.
2. The dependencies were re-installed. Actually, nothing happened, but Ansible doesn't know, because it's just running a shell script. We try and avoid running scripts when using configuration management systems such as Ansible, because they can be non-deterministic, and so always have to be run.
3. We reconfigured the supervisor to point to the new location.
4. We told the supervisor to restart the application.
5. We asked nginx to reload its configuration.

Using Ansible (or whatever else), we can easily throw away this server and set up a new one in just a few clicks. Once again, we've gone from configuring the server *imperatively* to *declaratively*, allowing us to define the whole state up-front before we start applying the configuration.

[Ansible]: https://www.ansible.com/
[Chef]: https://www.chef.io/chef/
[Puppet]: https://puppet.com/
[SaltStack]: https://saltstack.com/

## 01:00 — Now it's time to release a new version.

Let's make it blue.

*[Change it to blue. Can't be that hard. Try `#147086`.]*

All we need to do is make a couple of changes to the Ansible playbook. We'll add the following lines to the "Clone the repository" section:

```
        version: blue
        update: yes
```

*[Ship it, wait 30 seconds and reload.]*

Nice and easy. Ansible took care of figuring out what's changed and what's stayed the same. It updates the Git repository to point at our new version, then instructs the supervisor to restart it. It's only down for a few seconds while it restarts.

If you really can't go down, even for a second, there are more advanced techniques you can use. For example, you can use *blue-green deployment*. What this means is that we have two servers (codenamed "blue" and "green"). Only one of the servers is active at any time (this means that we somehow configured a third server, the "gateway", to redirect all traffic to this one). Let's assume it's the blue one. When we release, we release to the inactive (green) server, ensure that everything is healthy, then activate it. If it doesn't work, figure out why, and meanwhile, the blue server is still happily serving requests.

It's quite common to automate this kind of deployment either periodically or every time a commit gets pushed to the *master* branch. The latter is called *continuous deployment*. This is related to *continuous integration*. The idea is that each time you push, a server runs your Ansible playbook or other deployment mechanism for you. You could manage this server yourself, but you could also use [Travis CI][], [CircleCI][], [Shippable][] or another online service, which are often free to start.

[CircleCI]: https://circleci.com/
[Shippable]: https://www.shippable.com/
[Travis CI]: https://travis-ci.org/

## 01:10 — I compile my code, and it's private!

Right now, we're shipping Python and JavaScript, which we can just run from the source code. However, some language platforms require the source code to be *compiled* first. If this is the case, it's not enough to just clone the repository—you have to create a *release* and store it somewhere. If you use GitHub or Bitbucket, you'll find that there's a mechanism there for uploading releases, which you can then instruct Ansible to download.

You might also want to keep your code private. This is doable but requires that you configure Ansible to generate an SSH key, tell your host what it is, then use that to clone the repository or download the releases.

You could get Ansible to just copy the release from your local machine, but this means that you'll never be able to go back to an older release, as it'll get overwritten each time. For this reason, I wouldn't recommend it.

All of this is beyond the scope of this tutorial, but ask me more about it if you're curious.

## 01:15 — What if it goes down?

That'd be awful, right?

Fortunately, the Internet will let me know. I've configured [Pingdom][] to tell me if the site goes down. It'll send me an email within five minutes if it doesn't come back up sharpish.

*[Show the emails that have inevitably been sent in the last hour.]*

There are lots of tools just like Pingdom. Find the one you like. I recommend starting on a free trial to make sure it's right for you.

[Pingdom]: https://www.pingdom.com/

## 01:20 — What if it breaks?

It'd be nice to know what's going on on the server, especially if things are screwy. This is what logging is for.

Let's say, for example, that we introduce a bug into our application.

```sh
$ ansible-playbook ansible/predestination-broken.yaml
```

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

```sh
$ ansible-playbook ansible/predestination.yaml
```

## 01:30 — How do I store data?

Short answer: don't. At least not on your machine.

Remember how we've been using third-party services such as Pingdom, CircleCI and Amazon Web Services to manage parts of our stack? Let's introduce one more. Whatever your database, someone else is better at managing it than you. There are lots of free or cheap options, such as [ElephantSQL][], which provides PostgreSQL, a powerful relational database, [Compose][], which provides hosted versions of MongoDB, Redis, and other document-based databases, [Amazon RDS][], which provides a few different relational databases, and many more.

You might think it's easy or cheaper to run your own. And it may well be, until you accidentally delete some data or your hard drive breaks. At that point, you'll wish you paid for someone else to manage backups and redundancy.

And whatever you do, don't store data text files on the server. It's the easiest way to accidentally lose data.

[ElephantSQL]: https://www.elephantsql.com/
[Compose]: https://compose.com/
[Amazon RDS]: https://aws.amazon.com/rds/

## 01:35 — So what's all this Docker business?

Right. Here come the fireworks.

[Docker][] is a useful way of packaging up an application to handle all this stuff for you. All you need is the Docker daemon on the server and you can run an application really easily. It can be instructed to re-run the application if it crashes, just like supervisord, and can be set up with Ansible or another deployment tool. It also ships with one of its own, called [Docker Compose][].

Docker also packages everything. This means that you don't need to install anything on the server except Docker itself, as the *Docker image* that you build contains all the application dependencies. This includes Python (or whatever you want to use to make your web app).

```sh
$ ansible-playbook ansible/predestination-undo.yaml
$ ansible-playbook ansible/predestination-docker.yaml
```

The first Ansible playbook removes everything we set up earlier, including the supervisor configuration, nginx configuration and the application itself. The second deploys predestination from the publicly-available [samirtalwar/predestination][] Docker image.

*[Talk through the new playbook.]*

It's been around for a few years, so many don't consider it quite as stable as running on bare Linux, but personally, I think the convenience of packaging an entire application up locally is so good that I'm willing to make that trade-off. We no longer need to configure files on the server; we just instruct Docker to start a "container" from our image and away we go. It also means we can test our images locally and they'll work almost entirely the same, whether we're on Windows, macOS or Linux.

Building Docker images is beyond the scope of this tutorial, but I encourage you to have a go with it.

[Docker]: https://docs.docker.com/
[Docker Compose]: https://docs.docker.com/compose/
[samirtalwar/predestination]: https://hub.docker.com/r/samirtalwar/predestination/

## 01:45 — Any questions?

Let's talk.
