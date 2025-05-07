import boto3
import time
from typing import List, Dict, Any

lambda_client = boto3.client("lambda")
apigw_client = boto3.client("apigateway")
apigwv2_client = boto3.client("apigatewayv2")

SUPPORTED_RUNTIMES = {
    "java11", "java17", "java21", "java23",
    "python3.12", "python3.13",
    "dotnet8"
}
SUPPORTED_ARCHITECTURES = {"x86_64", "arm64"}

def check_lambda_snapstart() -> List[str]:
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

def check_apigateway_integrations() -> List[str]:
    issues = []

    # REST APIs
    rest_apis = apigw_client.get_rest_apis()["items"]
    for api in rest_apis:
        api_id = api["id"]
        resources = apigw_client.get_resources(restApiId=api_id)["items"]

        for res in resources:
            for method in res.get("resourceMethods", {}):
                integration = apigw_client.get_integration(
                    restApiId=api_id,
                    resourceId=res["id"],
                    httpMethod=method
                )
                uri = integration.get("uri", "")
                if ":$LATEST" in uri:
                    issues.append(f"REST API '{api['name']}' method {method} uses $LATEST (not compatible with SnapStart): {uri}")

    # HTTP APIs
    http_apis = apigwv2_client.get_apis()["Items"]
    for api in http_apis:
        api_id = api["ApiId"]
        integrations = apigwv2_client.get_integrations(ApiId=api_id)["Items"]

        for integ in integrations:
            target = integ.get("IntegrationUri", "")
            if ":$LATEST" in target:
                issues.append(f"HTTP API '{api['Name']}' uses $LATEST (not compatible with SnapStart): {target}")

    return issues

def invoke_functions() -> List[str]:
    results = []

    paginator = lambda_client.get_paginator("list_functions")
    for page in paginator.paginate():
        for fn in page["Functions"]:
            fn_name = fn["FunctionName"]
            try:
                start_time = time.time()
                response = lambda_client.invoke(
                    FunctionName=fn_name,
                    Payload=b"{}"
                )
                duration = time.time() - start_time
                results.append(f"{fn_name}: Invocation took {duration:.2f} seconds.")
            except Exception as e:
                results.append(f"{fn_name}: Invocation failed with error: {e}")

    return results

def main() -> None:
    lambda_issues = check_lambda_snapstart()
    apigw_issues = check_apigateway_integrations()
    invocation_results = invoke_functions()

    if not lambda_issues and not apigw_issues:
        print("✅ All Lambdas and API Gateways are SnapStart-compatible and properly configured.")
    else:
        print("❌ Issues found:")
        for issue in lambda_issues + apigw_issues:
            print(" -", issue)

    print("\nFunction invocation results:")
    for result in invocation_results:
        print(" -", result)

if __name__ == "__main__":
    main()
