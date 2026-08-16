package terratest

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

const defaultRegion = "ap-south-1"
const defaultAWSAccountID = "765574565805"

func repoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..", ".."))
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
	return defaultAWSAccountID
}

func verifyAWSAccount(t *testing.T, ctx context.Context, cfg aws.Config) {
	t.Helper()

	identity, err := sts.NewFromConfig(cfg).GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	require.NoError(t, err, "get AWS caller identity")

	actual := aws.ToString(identity.Account)
	expected := expectedAWSAccountID()
	t.Logf("AWS account=%s arn=%s", actual, aws.ToString(identity.Arn))

	require.Equal(t, expected, actual,
		"wrong AWS account — SSO/login to %s before running live tests (current: %s). Run: aws sts get-caller-identity",
		expected, actual)
}

func requiredVPCEndpointServices() []string {
	return []string{
		"ecr.api",
		"ecr.dkr",
		"sts",
		"eks",
	}
}

func requiredEKSAddons() []string {
	return []string{
		"vpc-cni",
		"kube-proxy",
		"eks-pod-identity-agent",
	}
}

func optionalEKSAddonsAfterNodes() []string {
	return []string{
		"coredns",
		"aws-ebs-csi-driver",
	}
}

func optionalTerraformOutput(t *testing.T, opts *terraform.Options, name string) (string, bool) {
	t.Helper()
	out, err := terraform.RunTerraformCommandE(t, opts, "output", "-no-color", "-raw", name)
	if err != nil {
		t.Logf("terraform output %q not in state (%v)", name, err)
		return "", false
	}
	out = strings.TrimSpace(out)
	if name == "cluster_name" && !isClusterNameOutput(out) {
		t.Logf("terraform output %q unusable (%q) — ignoring", name, out)
		return "", false
	}
	if out == "" {
		return "", false
	}
	return out, true
}

// isClusterNameOutput rejects terraform warning text and other non-cluster values.
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
