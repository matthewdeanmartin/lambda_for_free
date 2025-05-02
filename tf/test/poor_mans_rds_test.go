package test

import (
	"context"
	"testing"
	// "github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPostgresInfra(t *testing.T) {
	t.Parallel()

	awsRegion := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./poor_mans_rds_fixture",
		Vars: map[string]interface{}{
			"name":        "test-postgres",
			"environment": "test",
		},
		NoColor: false,
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION":    awsRegion,
			"AWS_PROFILE":           "moto",
			"AWS_ACCESS_KEY_ID":     "AKIAIOSFODNN7EXAMPLE",
			"AWS_SECRET_ACCESS_KEY": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	instanceID := terraform.Output(t, terraformOptions, "postgres_instance_id")
	// publicIP := terraform.Output(t, terraformOptions, "postgres_public_ip")
	postgresSgID := terraform.Output(t, terraformOptions, "postgres_sg_id")
	lambdaSgID := terraform.Output(t, terraformOptions, "lambda_sg_id")

	// Load AWS configuration
	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(awsRegion))
	require.NoError(t, err)

	ec2Client := ec2.NewFromConfig(cfg)

	// Describe EC2 instance
	instanceOutput, err := ec2Client.DescribeInstances(context.TODO(), &ec2.DescribeInstancesInput{
		InstanceIds: []string{instanceID},
	})
	require.NoError(t, err)
	require.Len(t, instanceOutput.Reservations, 1)
	require.Len(t, instanceOutput.Reservations[0].Instances, 1)

	instance := instanceOutput.Reservations[0].Instances[0]
	assert.Equal(t, "running", string(instance.State.Name))

	// Describe Security Group
	sgOutput, err := ec2Client.DescribeSecurityGroups(context.TODO(), &ec2.DescribeSecurityGroupsInput{
		GroupIds: []string{postgresSgID},
	})
	require.NoError(t, err)
	require.Len(t, sgOutput.SecurityGroups, 1)

	sg := sgOutput.SecurityGroups[0]

	// Check if port 5432 is open to Lambda SG
	var foundRule bool
	for _, perm := range sg.IpPermissions {
		if perm.FromPort != nil && *perm.FromPort == 5432 && perm.ToPort != nil && *perm.ToPort == 5432 && *perm.IpProtocol == "tcp" {
			for _, pair := range perm.UserIdGroupPairs {
				if *pair.GroupId == lambdaSgID {
					foundRule = true
					break
				}
			}
		}
	}
	assert.True(t, foundRule, "Expected rule from Lambda SG to port 5432")

	//// Optional: check if port 5432 is open on the public IP
	//time.Sleep(30 * time.Second) // wait for PostgreSQL to start
	//
	//isOpen := terraform.IsTcpPortOpen(publicIP, 5432)
	//assert.True(t, isOpen, "Expected port 5432 to be open on EC2 instance")
}
