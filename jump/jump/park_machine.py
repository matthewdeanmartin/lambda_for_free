#!/usr/bin/env python3

import boto3
import inquirer
from typing import List, Dict, Optional

ec2 = boto3.client("ec2")


def get_running_instances() -> List[Dict]:
    response = ec2.describe_instances(Filters=[
        {"Name": "instance-state-name", "Values": ["running"]}
    ])

    instances = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            name = None
            for tag in instance.get("Tags", []):
                if tag["Key"] == "Name":
                    name = tag["Value"]
            instances.append({
                "InstanceId": instance["InstanceId"],
                "Name": name or "(no name)",
                "State": instance["State"]["Name"]
            })
    return instances


def stop_instance(instance_id: str):
    ec2.stop_instances(InstanceIds=[instance_id])
    print(f"Sent stop request for {instance_id}")


def stop_all(instances: List[Dict]):
    ids = [i["InstanceId"] for i in instances]
    if ids:
        ec2.stop_instances(InstanceIds=ids)
        print(f"Sent stop request for all: {', '.join(ids)}")
    else:
        print("No running instances to stop.")


def prompt_action(instances: List[Dict]):
    choices = [
        f"{inst['Name']} ({inst['InstanceId']})" for inst in instances
    ]
    choices.append("🚪 Exit")
    choices.append("🛑 Park all")

    questions = [
        inquirer.List("choice", message="Which instance do you want to park?", choices=choices)
    ]
    answer = inquirer.prompt(questions)["choice"]
    return answer


def main():
    instances = get_running_instances()
    if not instances:
        print("No running instances found.")
        return

    while True:
        choice = prompt_action(instances)
        if choice == "🚪 Exit":
            break
        elif choice == "🛑 Park all":
            stop_all(instances)
            break
        else:
            selected = next(i for i in instances if f"{i['Name']} ({i['InstanceId']})" == choice)
            stop_instance(selected["InstanceId"])
            instances = get_running_instances()
            if not instances:
                print("All instances parked.")
                break


if __name__ == "__main__":
    main()
