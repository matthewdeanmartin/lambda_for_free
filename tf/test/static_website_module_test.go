package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestStaticWebsiteViaModule(t *testing.T) {
	t.Parallel()

	// Define options
	tfOptions := &terraform.Options{
		TerraformDir: "../modules/static_website",
		NoColor:      false,
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    "us-east-1",
			"AWS_ACCESS_KEY_ID":     "AKIAIOSFODNN7EXAMPLE",
			"AWS_SECRET_ACCESS_KEY": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
		},
		Vars: map[string]interface{}{
			"bucket_name": "terratest-static-website",
			"tags": map[string]string{
				"Name": "terratest-static-website",
			},
		},
	}

	// Destroy on test exit
	defer terraform.Destroy(t, tfOptions)

	// Init and apply
	terraform.InitAndApply(t, tfOptions)

	// Get outputs
	bucketName := terraform.Output(t, tfOptions, "bucket_name")
	domainName := terraform.Output(t, tfOptions, "bucket_domain_name")

	// Assertions
	assert.True(t, strings.HasPrefix(bucketName, "terratest-static-"), "Bucket name should start with terratest-static-")
	assert.Contains(t, domainName, ".s3.", "Expected a bucket domain name containing .s3.")
	fmt.Printf("Tested S3 Bucket: %s\n", bucketName)
}
