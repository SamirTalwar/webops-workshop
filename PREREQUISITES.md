# Prerequisites

You'll need a server.

## 1. Client-side preparation

Install:

1. An SSH client.
    1. If you're on macOS or Linux, you have one built in.
    2. On Windows 10, you can install [Bash on Windows][Bash on Windows Installation Guide].
    3. On any other version of Windows, download and install [PuTTY][].
2. An SSH key specifically for the job.
    1. If you're running on macOS, Linux, or Bash on Windows, run `ssh-keygen` and store the key at *~/.ssh/webops*. (You may need to replace "~" with the absolute path to your home directory.)
    2. If you're using PuTTY, run *puttygen.exe* and name the key "webops".
3. [Terraform][].
4. [Ansible][].
5. [mosh][] (if available for your platform), which is like SSH (and uses it to bootstrap itself) but can handle flaky connections much more gracefully.

Then clone this repository. All local commands are expected to be run from the root of this repository unless specified otherwise.

[Ansible]: https://www.ansible.com/
[Bash on Windows Installation Guide]: https://msdn.microsoft.com/en-us/commandline/wsl/install_guide
[PuTTY]: http://www.chiark.greenend.org.uk/~sgtatham/putty/
[Terraform]: https://www.terraform.io/
[mosh]: https://mosh.org/

## 2. Create a server

This uses Amazon Web Services. If you'd rather use another cloud provider, you'll need to configure it yourself.

1. If you haven't already, create an account on [Amazon Web Services][].
2. Pick your favourite AWS region, grab your VPC ID and subnet ID, and create a file called *terraform/terraform.tfvars* as follows:
   ```
   region = "<Region>"
   vpc_id = "<VPC ID>"
   subnet_id = "<Subnet ID>"
   ```
3. If you're creating instances for lots of people, add a line to *terraform/terraform.tfvars* with the number:
   ```
   count = <number of instances>
   ```
4. `cd` into the *terraform* directory.
5. Run `terraform init` to set it up.
6. Run `terraform plan`, then check the plan.
7. If you're happy, run `terraform apply`. This will create a server and configure it with everything necessary to run our example application, [Predestination][].
8. `cd ..` back into the root directory.

[Amazon Web Services]: https://aws.amazon.com/
[Predestination]: https://github.com/SamirTalwar/predestination

## 3. Set up the dependencies

If you're using our example application, [Predestination][], you'll need a bunch of dependencies. (And if you're not, they can't hurt.)

1. Verify that *ansible/inventory* has been created with the IP address of your server.
2. Tell Ansible to install everything:
   ```sh
   ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_INVENTORY=ansible/inventory ansible-playbook ansible/prerequisites.yaml
   ```
