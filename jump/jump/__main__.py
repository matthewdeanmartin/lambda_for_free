from __future__ import annotations
import argparse
import boto3
import json
import subprocess
import sys
from pathlib import Path
from typing import Optional, Literal

AWS_SSH_KEY_PATH: Path = Path.home() / ".ssh"
AWS_SSH_KEY_NAME = "aws_ssm_ssh_key"
SSH_USER = "ec2-user"
SSH_PUBLIC_KEY_TIMEOUT = 120


def get_ec2_instance_choices() -> list[dict]:
    """
    Retrieve a list of EC2 instance dictionaries.
    """
    filters = [
        {"Name": "instance-state-name", "Values": ["running"]},
    ]
    ec2 = boto3.client("ec2")
    reservations = ec2.describe_instances(Filters=filters).get("Reservations", [])
    instances = [
        instance
        for reservation in reservations
        for instance in reservation.get("Instances", [])
    ]
    return instances


def choose_instance(instances: list[dict]) -> Optional[str]:
    """
    Present a menu of instances and return the chosen instance ID.
    """
    if not instances:
        print("No EC2 instances found.")
        return None

    print("Select an EC2 instance:")
    for idx, inst in enumerate(instances, start=1):
        name = next(
            (tag["Value"] for tag in inst.get("Tags", []) if tag["Key"] == "Name"), "N/A"
        )
        print(f"{idx}: {inst['InstanceId']} ({name})")

    choice = int(input("Enter a number: "))
    return instances[choice - 1]["InstanceId"]


def get_calling_user() -> str:
    """
    Retrieve the current AWS caller identity.
    """
    sts = boto3.client("sts")
    arn = sts.get_caller_identity()["Arn"]
    return arn.split("/")[-1]


def get_ssh_public_key() -> str:
    """
    Return the contents of the SSH public key, creating it if needed.
    """
    key_path = AWS_SSH_KEY_PATH / AWS_SSH_KEY_NAME
    pub_key_path = key_path.with_suffix(".pub")
    if not pub_key_path.exists():
        create_ssh_key_pair()
    return pub_key_path.read_text().strip()


def create_ssh_key_pair() -> None:
    """
    Generate a new SSH key pair for use with EC2 instances.
    """
    subprocess.run(
        [
            "ssh-keygen",
            "-t",
            "rsa",
            "-C",
            "ec2-ssm",
            "-f",
            str(AWS_SSH_KEY_PATH / AWS_SSH_KEY_NAME),
            "-P",
            "",
            "-q",
        ],
        check=True,
    )


def connect(
    instance_id: str,
    ssh_user: str,
    conn_type: Optional[Literal["tunnel", "tunnel-socket"]],
    tunnel_domain: Optional[str],
    tunnel_port: Optional[str],
    host_port: Optional[str],
) -> None:
    """
    Add SSH key to remote instance's authorized_keys and start an SSH session or tunnel.
    """
    ssh_key_path = AWS_SSH_KEY_PATH / AWS_SSH_KEY_NAME
    ssh_public_key = get_ssh_public_key()
    aws_user = get_calling_user()

    ssm = boto3.client("ssm")

    ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={
            "commands": [f"""
sudo su
mkdir -p ~{ssh_user}/.ssh
chown -R {ssh_user}:{ssh_user} ~{ssh_user}/.ssh
cd ~{ssh_user}/.ssh || exit 1
grep -F '{ssh_public_key}' authorized_keys || echo '{ssh_public_key} {aws_user}' >> authorized_keys
sleep {SSH_PUBLIC_KEY_TIMEOUT}
grep -v -F '{ssh_public_key}' authorized_keys > .tmp.authorized_keys
mv .tmp.authorized_keys authorized_keys
"""]
        },
        Comment=f"{aws_user} - grant ssh access for {SSH_PUBLIC_KEY_TIMEOUT} seconds",
    )

    remote = f"{ssh_user}@{instance_id}"
    if conn_type == "tunnel":
        tunnel_domain = tunnel_domain or "localhost"
        tunnel_port = tunnel_port or "5432"
        host_port = host_port or "5555"

    if conn_type == "tunnel" and tunnel_domain and tunnel_port and host_port:
        subprocess.run(
            [
                "ssh",
                "-t",
                "-i",
                str(ssh_key_path),
                "-L",
                f"{host_port}:{tunnel_domain}:{tunnel_port}",
                remote,
                "read -r -d '' _",
            ]
        )
    elif conn_type == "tunnel-socket" and tunnel_domain and tunnel_port and host_port:
        subprocess.run(
            [
                "ssh",
                "-M",
                "-S",
                f"/tmp/{host_port}-control-socket",
                "-i",
                str(ssh_key_path),
                "-fNT",
                "-L",
                f"{host_port}:{tunnel_domain}:{tunnel_port}",
                remote,
            ]
        )
    else:
        subprocess.run(["ssh", "-i", str(ssh_key_path), remote])


def close_socket(instance_id: str, host_port: str) -> None:
    """
    Close an SSH control socket tunnel to the given instance.
    """
    ssh_key_path = AWS_SSH_KEY_PATH / AWS_SSH_KEY_NAME
    subprocess.run(
        [
            "ssh",
            "-S",
            f"/tmp/{host_port}-control-socket",
            "-i",
            str(ssh_key_path),
            "-O",
            "exit",
            f"{SSH_USER}@{instance_id}",
        ]
    )

def proxy_command(host: str, port: str) -> None:
    """
    Acts as a ProxyCommand for SSH, starting an SSM session to the given host and port.
    """
    subprocess.run([
        "aws", "ssm", "start-session",
        "--target", host,
        "--document-name", "AWS-StartSSHSession",
        "--parameters", f"portNumber={port}"
    ])

def cli() -> None:
    parser = argparse.ArgumentParser(prog="ec2-ssm-ssh")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Connect
    conn_parser = subparsers.add_parser("connect", help="SSH or tunnel into a remote EC2 instance")
    conn_parser.add_argument("-t", "--type", choices=["tunnel", "tunnel-socket"])
    conn_parser.add_argument("--tunnel-domain")
    conn_parser.add_argument("--tunnel-port")
    conn_parser.add_argument("--host-port")

    # Close tunnel
    close_parser = subparsers.add_parser("close-socket", help="Close an open SSH control socket")
    close_parser.add_argument("--host-port", required=True)

    # Proxy command (for use in ~/.ssh/config)
    proxy_parser = subparsers.add_parser("proxy", help="Start an SSM session as SSH ProxyCommand")
    proxy_parser.add_argument("host", help="EC2 instance ID (i-*)")
    proxy_parser.add_argument("port", help="Port to connect to on the remote instance")

    args = parser.parse_args()

    instances = get_ec2_instance_choices()
    instance_id = choose_instance(instances)
    if not instance_id:
        sys.exit(1)

    if args.command == "connect":
        connect(
            instance_id,
            SSH_USER,
            args.type,
            args.tunnel_domain,
            args.tunnel_port,
            args.host_port,
        )
    elif args.command == "close-socket":
        close_socket(instance_id, args.host_port)
    elif args.command == "proxy":
        proxy_command(args.host, args.port)
    else:
        print("Unknown command. Use --help for usage information.")
        sys.exit(1)


if __name__ == "__main__":
    cli()
