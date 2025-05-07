# snapstart_checker.py

import boto3
from typing import List

SUPPORTED_RUNTIMES = {"java11", "java17", "java21", "java23", "python3.12", "python3.13", "dotnet8"}
SUPPORTED_ARCHITECTURES = {"x86_64", "arm64"}

def check_lambda_snapstart(lambda_client) -> List[str]:
    paginator = lambda_client.get_paginator("list_functions")
    issues = []

    for page in paginator.paginate():
        for fn in page["Functions"]:
            fn_name = fn["FunctionName"]
            arch = fn.get("Architectures", ["x86_64"])[0]
            runtime = fn["Runtime"]

            config = lambda_client.get_function_configuration(FunctionName=fn_name)
            snapstart_conf = config.get("SnapStart", {})
            snap_enabled = snapstart_conf.get("ApplyOn", None)

            if runtime not in SUPPORTED_RUNTIMES:
                issues.append(f"{fn_name}: Runtime '{runtime}' not supported by SnapStart.")

            if arch not in SUPPORTED_ARCHITECTURES:
                issues.append(f"{fn_name}: Architecture '{arch}' not supported by SnapStart.")

            if snap_enabled != "PublishedVersions":
                issues.append(f"{fn_name}: SnapStart not enabled.")

            # Check for published versions
            versions = lambda_client.list_versions_by_function(FunctionName=fn_name)["Versions"]
            published = [v for v in versions if v["Version"] != "$LATEST"]
            if not published:
                issues.append(f"{fn_name}: No published versions (SnapStart requires published versions).")

    return issues
