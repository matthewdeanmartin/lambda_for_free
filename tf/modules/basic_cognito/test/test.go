package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCognitoModule(t *testing.T) {
	t.Parallel()

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/cognito",

		Vars: map[string]interface{}{
			"product":               "myproduct",
			"environment":           "test",
			"domain_prefix":         "myproduct-auth-test-domain",
			"android_callback_urls": []string{"myapp://callback"},
			"lambda_callback_urls":  []string{"https://lambda.example.com/callback"},
			"django_callback_urls":  []string{"https://web.example.com/callback"},
		},
		Upgrade: true,
	}

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply"
	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs
	userPoolID := terraform.Output(t, terraformOptions, "user_pool_id")
	assert.NotEmpty(t, userPoolID, "user_pool_id should not be empty")

	userPoolDomain := terraform.Output(t, terraformOptions, "user_pool_domain")
	assert.Equal(t, "myproduct-auth-test-domain", userPoolDomain)

	clientIDs := terraform.OutputMap(t, terraformOptions, "client_ids")
	assert.Contains(t, clientIDs, "django")
	assert.Contains(t, clientIDs, "android")
	assert.Contains(t, clientIDs, "lambda")

	clientSecret := terraform.Output(t, terraformOptions, "client_secrets")
	assert.NotEmpty(t, clientSecret, "Django client secret should be set")

	groupNames := terraform.OutputList(t, terraformOptions, "group_names")
	expectedGroups := []string{"free-user", "paid-user", "staff", "admin"}
	for _, expected := range expectedGroups {
		assert.Contains(t, groupNames, expected)
	}

	// Optional: basic sanity check on ID formats
	assert.True(t, strings.HasPrefix(userPoolID, "us-"), "user_pool_id looks valid")
}
