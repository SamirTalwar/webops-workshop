# Prerequisites

You'll need a server. There are a few ways to create one.

1. Client-side preparation
2. Create a server
  1. with an Ubuntu VM image I made earlier
  2. as a Virtualbox VM from scratch
  3. on Amazon Web Services
  4. on your own cloud server
3. Install the necessary dependencies

Pick your path and go.

## 1. Client-side preparation

Install:

1. An SSH client.
    1. If you're on macOS or Linux, you have one built in.
    2. On Windows 10, you can install [Bash on Windows][Bash on Windows Installation Guide].
    3. On any other version of Windows, download and install [PuTTY][].
2. An SSH key. You may have one already. If so, skip this.
    1. If you're running on macOS, Linux, or Bash on Windows, it will be located at *~/.ssh/id_rsa* or *~/.ssh/id_dsa*. If not, just run `ssh-keygen`.
    2. If you're using PuTTY, run *puttygen.exe*.
3. [Ansible][].
4. [mosh][] (if available for your platform), which is like SSH (and uses it to bootstrap itself) but can handle flaky connections much more gracefully.

[Bash on Windows Installation Guide]: https://msdn.microsoft.com/en-us/commandline/wsl/install_guide
[PuTTY]: http://www.chiark.greenend.org.uk/~sgtatham/putty/
[Ansible]: https://www.ansible.com/
[mosh]: https://mosh.org/

## 2a. Create an Ubuntu VM with an image I made earlier

If you'd rather not use this VM, you can create one yourself as described in step 2b.

1. [Download the VM image.][webops-workshop.ova]
2. Import the *.ova* file into [VirtualBox][].
3. Once it's imported, click "Network" and add a second "Host-Only" network adapter.
4. Remember that the username is "webops" and the password is "let me in please".
5. Start the VM.
6. Get the VM's IP address (`ip address`). It probably has more than one. If you don't have a 192.168.x.x address, you'll need to edit */etc/network/interfaces* and add the following lines:
   ```
   auto enp0s8
   iface enp0s8 inet dhcp
   ```
   Then run `sudo service networking restart`.
7. Set up your SSH configuration by adding the following to *~/.ssh/config*:
   ```
   Host webops
       Hostname <VM IP>
       User webops
   ```
8. Copy the SSH key to the server VM (you'll need to provide your password for each command):
   ```sh
   $ ssh webops mkdir ~/.ssh
   $ scp ~/.ssh/id_rsa.pub webops:~/.ssh/authorized_keys
   ```
9. SSH in with `ssh webops`. You shouldn't need your password.
10. Shut the VM down and take a snapshot.
11. Create a file called *ansible/inventory*:
    ```
    <VM IP> ansible_user=webops
    ```

[webops-workshop.ova]: https://s3-eu-west-1.amazonaws.com/noodlesandwich.com/talks/webops/ubuntu-vm.ova
[VirtualBox]: https://www.virtualbox.org/

## 2b. Create your own Ubuntu VM

A fresh [Ubuntu Server 16.04.2 LTS][Download Ubuntu Server] virtual machine. This will be distributed beforehand, but you can skip to step 4 if you want to create one yourself, or make one on The Cloud™ if you know what you're doing.

1. Start downloading the ISO.
2. Create a new [VirtualBox][] VM named "WebOps Workshop".
3. Pick *Linux*, then *Ubuntu (64-bit)* as the operating system.
4. Give it 2048 MB of RAM.
5. Allow it to create a hard disk, with all the defaults.
6. Once it's created, click "Storage" and assign the ISO to the optical drive.
7. Hop over to the "Network" tab and add a second "Host-Only" network adapter.
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
14. Reboot to ensure everything's working.
15. Get the VM's IP address (`ip address`). It probably has more than one. If you don't have a 192.168.x.x address, you'll need to edit */etc/network/interfaces* and add the following lines:
    ```
    auto enp0s8
    iface enp0s8 inet dhcp
    ```
    Then run `sudo service networking restart`.
16. Set up your SSH configuration by adding the following to *~/.ssh/config*:
    ```
    Host webops
        Hostname <VM IP>
        User webops
    ```
17. Copy the SSH key to the server VM (you'll need to provide your password for each command):
    ```sh
    $ ssh webops mkdir ~/.ssh
    $ scp ~/.ssh/id_rsa.pub webops:~/.ssh/authorized_keys
    ```
18. SSH in with `ssh webops`. You shouldn't need your password.
19. Shut the VM down and take a snapshot.
20. Create a file called *ansible/inventory*:
    ```
    <VM IP> ansible_user=webops
    ```

[Download Ubuntu Server]: https://www.ubuntu.com/download/server

## 2c. Create your own VM on Amazon Web Services

1. Create an AWS server with Ubuntu 16.04 (Xenial), and save the PEM as *~/.ssh/\<something\>.pem* with a chmod of 600.
2. In the security group, open TCP ports 80, 443 and 8080, and UDP ports 60000-61000 (for Mosh).
3. Set up your SSH configuration by adding the following to *~/.ssh/config*:
   ```
   Host webops
       Hostname <hostname>
       User ubuntu
       IdentityFile <path to PEM file>
   ```
5. SSH in with `ssh webops`. You shouldn't need a password. Once you've proven that you can, disconnect.
6. Create a file called *ansible/inventory*:
   ```
   <hostname> ansible_user=ubuntu ansible_ssh_private_key_file=<path to PEM file>
   ```

## 2d. Create your own VM on another cloud provider

You're on your own for this one. Make sure it runs Ubuntu, follow the instructions for AWS as best you can, and away you go.

## 3. Install the necessary dependencies

Assuming we're using the [Predestination][] app, you'll need the following too. Don't worry how it works for now. All will be explained later.

```sh
$ ansible-playbook ansible/prerequisites.yaml
```

(If it fails because you need your password to `sudo`, add the `--ask-sudo-pass` switch to the end.)

[Predestination]: https://github.com/SamirTalwar/predestination
