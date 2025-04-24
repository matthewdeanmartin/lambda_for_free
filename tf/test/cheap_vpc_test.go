package test

import (
	//"fmt"
	// "github.com/gruntwork-io/terratest/modules/collection"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	//"strings"
	"testing"
)

// Test the SQS queue creation
func TestBuildAll(t *testing.T) {
	t.Parallel()

	// Set up Terraform options
	terraformOptions := &terraform.Options{
		// Path to the Terraform code
		TerraformDir: "../",

		// Variables to pass to our Terraform code
		Vars: map[string]interface{}{
			"environment": "terratest", // or "prod"
		},

		// Variables to set in the Terraform configuration
		NoColor: true,
	}

	// Clean up resources after testing
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply the Terraform configuration
	terraform.InitAndApply(t, terraformOptions)

	// Get the SQS queue URL
	output := terraform.Output(t, terraformOptions, "rest_gateway_name")

	//// Ensure the queue URL is not empty
	assert.NotEmpty(t, output)
	//
	//// Ensure the correct queue name is generated based on the environment
	//expectedQueueName := fmt.Sprintf("todo-list-%s", "dev")
	//assert.True(t, strings.Contains(queueURL, expectedQueueName), "Queue URL does not match expected format")
	//
	//// Additional validation of the SQS attributes (if necessary)
	//queueAttributes := terraform.OutputMap(t, terraformOptions, "sqs_queue_attributes")
	//
	//// Check for some default attributes
	//assert.NotEmpty(t, queueAttributes["VisibilityTimeout"])
	//assert.Equal(t, "30", queueAttributes["VisibilityTimeout"])
}
