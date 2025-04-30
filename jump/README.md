# Jump

This is a python script to make it easier to connect to a jumpbox or ec2 server that:

- Has no public IP address
- Has public IP address, but no security group with open ports
- Has no initial SSH key
- Uses ssh over SSM

## Installation

```bash
poetry env use /C/Users/matth/AppData/Local/Programs/Python/Python313/python.exe
poetry lock && poetry install --with dev --sync
poetry shell
# Get credentials with `granted`
assume
python -m jump --help
```


## Help

```english
❯ python -m jump --help
usage: ec2-ssm-ssh [-h] {connect,close-socket,proxy} ...

positional arguments:
  {connect,close-socket,proxy}
    connect             SSH or tunnel into a remote EC2 instance
    close-socket        Close an open SSH control socket
    proxy               Start an SSM session as SSH ProxyCommand

options:
  -h, --help            show this help message and exit
```