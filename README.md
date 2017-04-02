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

### 00:00 — Introduction

A short introduction to deploying and running a website.

### 00:10 — Make sure everyone has a machine working

Hopefully not many people will have had trouble installing a VM and setting up SSH keys. In any case, pair them up, so only half of them need to.

In case everyone has had issues, take 10 minutes to sort them all out.

### 00:20 — Set up the server

### 00:20 — Start a web app on the server

Pick an app that takes `PORT` as an environment variable.

[Here's one I wrote][Predestination], in case you're stuck. If you use it:

```sh
sudo add-apt-repository ppa:jonathonf/python-3.6
sudo apt update
sudo apt upgrade
sudo apt install make virtualenv python3.6
make site-packages
# run `make web` to start it
```

Then run it:

```sh
PORT=8080 ./run # or however you start the application
```

*[Browse to the URL and show it off. If possible, leave the browser window open. It will automatically reconnect if you terminate the server and restart it.]*

Note that we're using the port 8080. HTTP usually runs over port 80, but we can't start an application there without it running as *root*, and we don't want to do that, as an attacker compromising the web server could get access to anything else.

In fact, we probably want to make sure the application has as few rights as possible. So let's create a user just for that.

```sh
sudo useradd web
sudo --user=web PORT=8080 ./run
```

*[Leave it running for a few seconds, then kill it again.]*

[Predestination]: https://github.com/SamirTalwar/predestination
