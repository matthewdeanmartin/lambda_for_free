import boto3
import time
import logging
from typing import List, Dict

# Logging setup
logging.basicConfig(
    format="%(asctime)s %(levelname)s: %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

lambda_client = boto3.client("lambda")
apigw_client = boto3.client("apigateway")
apigwv2_client = boto3.client("apigatewayv2")

SUPPORTED_RUNTIMES = {
    "java11", "java17", "java21", "java23",
    "python3.12", "python3.13",
    "dotnet8"
}
SUPPORTED_ARCHITECTURES = {"x86_64", "arm64"}

def check_lambda_snapstart_aliases() -> Dict[str, str]:
    logger.info("Checking Lambda SnapStart and aliases")
    issues = {}
    paginator = lambda_client.get_paginator("list_functions")

    for page in paginator.paginate():
        for fn in page["Functions"]:
            fn_name = fn["FunctionName"]
            arch = fn.get("Architectures", ["x86_64"])[0]
            runtime = fn["Runtime"]
            logger.debug(f"{fn_name} runtime={runtime}, arch={arch}")

            config = lambda_client.get_function_configuration(FunctionName=fn_name)
            snapstart = config.get("SnapStart", {})
            snap_enabled = snapstart.get("ApplyOn", "")

            if runtime not in SUPPORTED_RUNTIMES:
                issues[fn_name] = f"Unsupported runtime '{runtime}'"
            elif arch not in SUPPORTED_ARCHITECTURES:
                issues[fn_name] = f"Unsupported architecture '{arch}'"
            elif snap_enabled != "PublishedVersions":
                issues[fn_name] = "SnapStart not enabled on published versions"
            else:
                versions = lambda_client.list_versions_by_function(FunctionName=fn_name)["Versions"]
                published_versions = [v for v in versions if v["Version"] != "$LATEST"]
                aliases = lambda_client.list_aliases(FunctionName=fn_name)["Aliases"]
                alias_targets = {a["Name"]: a["FunctionVersion"] for a in aliases}

                if not published_versions:
                    issues[fn_name] = "No published versions"
                elif not alias_targets:
                    issues[fn_name] = "No aliases (needed for stable API Gateway integration)"
                else:
                    logger.debug(f"{fn_name} aliases: {alias_targets}")
                    print(f"✓ {fn_name} has SnapStart and aliases: {', '.join(alias_targets)}")
                    continue  # success path

            logger.info(f"Issue with {fn_name}: {issues[fn_name]}")

    return issues

def check_apigateway_integrations() -> List[str]:
    logger.info("Checking API Gateway integrations")
    issues = []

    # REST APIs
    rest_apis = apigw_client.get_rest_apis()["items"]
    print(f"\nFound {len(rest_apis)} REST APIs")
    for api in rest_apis:
        api_id = api["id"]
        name = api["name"]
        resources = apigw_client.get_resources(restApiId=api_id)["items"]

        print(f"REST API: {name}")
        for res in resources:
            for method in res.get("resourceMethods", {}):
                integration = apigw_client.get_integration(
                    restApiId=api_id,
                    resourceId=res["id"],
                    httpMethod=method
                )
                uri = integration.get("uri", "")
                logger.debug(f"{name} {method} URI: {uri}")
                if ":$LATEST" in uri:
                    issues.append(f"{name} method {method} uses $LATEST: {uri}")
                elif ":${" not in uri and not uri.split(":")[-1].isalpha():
                    issues.append(f"{name} method {method} uses hardcoded version instead of alias: {uri}")
                else:
                    print(f"✓ REST API '{name}' method {method} uses alias: {uri}")

    # HTTP APIs
    http_apis = apigwv2_client.get_apis()["Items"]
    print(f"\nFound {len(http_apis)} HTTP APIs")
    for api in http_apis:
        api_id = api["ApiId"]
        name = api["Name"]
        integrations = apigwv2_client.get_integrations(ApiId=api_id)["Items"]

        print(f"HTTP API: {name}")
        for integ in integrations:
            uri = integ.get("IntegrationUri", "")
            logger.debug(f"{name} integration URI: {uri}")
            if ":$LATEST" in uri:
                issues.append(f"{name} uses $LATEST: {uri}")
            elif ":${" not in uri and not uri.split(":")[-1].isalpha():
                issues.append(f"{name} uses hardcoded version instead of alias: {uri}")
            else:
                print(f"✓ HTTP API '{name}' integration uses alias: {uri}")

    return issues

def invoke_alias_targets() -> List[str]:
    logger.info("Invoking aliases and gathering logs")
    results = []
    paginator = lambda_client.get_paginator("list_functions")
    logs_client = boto3.client("logs")
    alias_name = "N/A"

    for page in paginator.paginate():
        for fn in page["Functions"]:
            fn_name = fn["FunctionName"]
            try:
                aliases = lambda_client.list_aliases(FunctionName=fn_name)["Aliases"]
                for alias in aliases:
                    alias_name = alias["Name"]
                    qualified_name = f"{fn_name}:{alias_name}"
                    log_group = f"/aws/lambda/{fn_name}"

                    logger.debug(f"Invoking {qualified_name}")
                    start_time_ms = int(time.time() * 1000)

                    lambda_client.invoke(
                        FunctionName=qualified_name,
                        Payload=b"{}"
                    )

                    # Small sleep to let logs propagate
                    time.sleep(2)

                    # Get the most recent log streams
                    streams = logs_client.describe_log_streams(
                        logGroupName=log_group,
                        orderBy="LastEventTime",
                        descending=True,
                        limit=1
                    )["logStreams"]

                    if not streams:
                        print(f"{qualified_name}: No logs found, looked in {log_group}.")
                        continue

                    log_stream = streams[0]["logStreamName"]
                    logger.debug(f"{qualified_name} log stream: {log_stream}")

                    log_events = logs_client.get_log_events(
                        logGroupName=log_group,
                        logStreamName=log_stream,
                        # startTime=start_time_ms,
                        startFromHead=True
                    )["events"]

                    print(f"\n📄 Logs for {qualified_name}, {len(log_events)} events")
                    for event in log_events:
                        message = event["message"]
                        if "SnapStart" in message or "Restore" in message:
                            print("  🧊", message.strip())
                        else:
                            logger.debug(f"{qualified_name} log: {message.strip()}")

                    results.append(f"{qualified_name}: invoked and logs gathered")

            except Exception as e:
                logger.warning(f"{fn_name} failed to invoke or fetch logs")
                results.append(f"{fn_name} alias {alias_name} failed: {e}")

    return results


def main() -> None:
    lambda_issues = check_lambda_snapstart_aliases()
    apigw_issues = check_apigateway_integrations()
    invocations = invoke_alias_targets()

    print("\nSummary:")
    if not lambda_issues and not apigw_issues:
        print("✅ All Lambdas and API Gateway integrations are SnapStart-compatible and use aliases.")
    else:
        print("❌ Issues found:")
        for fn, msg in lambda_issues.items():
            print(f" - Lambda: {fn} → {msg}")
        for issue in apigw_issues:
            print(f" - API GW: {issue}")

    print("\nInvocation results:")
    for result in invocations:
        print(" -", result)

if __name__ == "__main__":
    main()
