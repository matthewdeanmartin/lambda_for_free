#!/usr/bin/env python3

import boto3
import inquirer
from typing import List, Dict

ec2 = boto3.client("ec2")


def get_stopped_instances() -> List[Dict]:
    response = ec2.describe_instances(Filters=[
        {"Name": "instance-state-name", "Values": ["stopped"]}
    ])

    instances = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            name = next((tag["Value"] for tag in instance.get("Tags", []) if tag["Key"] == "Name"), "(no name)")
            instances.append({
                "InstanceId": instance["InstanceId"],
                "Name": name,
                "State": instance["State"]["Name"]
            })
    return instances


def start_instance(instance_id: str):
    ec2.start_instances(InstanceIds=[instance_id])
    print(f"Sent start request for {instance_id}")


def start_all(instances: List[Dict]):
    ids = [i["InstanceId"] for i in instances]
    if ids:
        ec2.start_instances(InstanceIds=ids)
        print(f"Sent start request for all: {', '.join(ids)}")
    else:
        print("No stopped instances to start.")


def prompt_action(instances: List[Dict]) -> str:
    choices = [f"{inst['Name']} ({inst['InstanceId']})" for inst in instances]
    choices.append("🚪 Exit")
    choices.append("🚀 Start all")

    questions = [
        inquirer.List("choice", message="Which instance do you want to unpark (start)?", choices=choices)
    ]
    return inquirer.prompt(questions)["choice"]


def main():
    instances = get_stopped_instances()
    if not instances:
        print("No parked (stopped) instances found.")
        return

    while True:
        choice = prompt_action(instances)
        if choice == "🚪 Exit":
            break
        elif choice == "🚀 Start all":
            start_all(instances)
            break
        else:
            selected = next(i for i in instances if f"{i['Name']} ({i['InstanceId']})" == choice)
            start_instance(selected["InstanceId"])
            instances = get_stopped_instances()
            if not instances:
                print("All instances started.")
                break


if __name__ == "__main__":
    main()
