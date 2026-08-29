package test

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

const (
	defaultRegion = "ap-south-1"
)

var allEnvironments = []string{"dev", "staging", "prod"}

func repoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), ".."))
}

func environmentDir(env string) string {
	return filepath.Join(repoRoot(), "environments", env)
}

func testEnvironment() string {
	if env := os.Getenv("TEST_ENVIRONMENT"); env != "" {
		return env
	}
	return "dev"
}

func awsRegion() string {
	if region := os.Getenv("AWS_REGION"); region != "" {
		return region
	}
	return defaultRegion
}

func expectedClusterName(env string) string {
	return fmt.Sprintf("eks-%s-eks", env)
}

func expectedAWSAccountID() string {
	if accountID := os.Getenv("TEST_AWS_ACCOUNT_ID"); accountID != "" {
		return accountID
	}
	return ""
}

func skipLiveChecks() bool {
	return os.Getenv("TERRATEST_SKIP_LIVE") == "true"
}

func verifyAWSAccount(t *testing.T, ctx context.Context, cfg aws.Config) {
	t.Helper()

	identity, err := sts.NewFromConfig(cfg).GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	require.NoError(t, err, "get AWS caller identity")

	actual := aws.ToString(identity.Account)
	expected := expectedAWSAccountID()
	t.Logf("AWS account=%s arn=%s", actual, aws.ToString(identity.Arn))

	if expected == "" {
		t.Log("TEST_AWS_ACCOUNT_ID not set — skipping account ID assertion")
		return
	}

	require.Equal(t, expected, actual,
		"wrong AWS account — login to %s before live tests (current: %s)",
		expected, actual)
}

func requiredVPCEndpointServices() []string {
	return []string{"ecr.api", "ecr.dkr", "sts", "eks"}
}

func requiredEKSAddons() []string {
	return []string{"vpc-cni", "kube-proxy", "eks-pod-identity-agent"}
}

func optionalEKSAddonsAfterNodes() []string {
	return []string{"coredns", "aws-ebs-csi-driver"}
}

func isClusterNameOutput(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" || strings.Contains(value, "\n") || strings.HasPrefix(value, "Warning:") {
		return false
	}
	return strings.HasPrefix(value, "eks-") && strings.HasSuffix(value, "-eks") && len(value) <= 64
}

func vpcEndpointShortName(serviceName string) string {
	switch {
	case strings.Contains(serviceName, ".ecr.api"):
		return "ecr.api"
	case strings.Contains(serviceName, ".ecr.dkr"):
		return "ecr.dkr"
	case strings.Contains(serviceName, ".elasticloadbalancing"):
		return "elasticloadbalancing"
	case strings.HasSuffix(serviceName, ".s3"):
		return "s3"
	default:
		parts := strings.Split(serviceName, ".")
		if len(parts) > 0 {
			return parts[len(parts)-1]
		}
		return serviceName
	}
}

func terraformOptions(env string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: environmentDir(env),
		NoColor:      true,
	}
}
