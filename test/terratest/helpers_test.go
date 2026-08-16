package terratest

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

const defaultRegion = "ap-south-1"

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
		t.Logf("terraform output %q not in state (%v) — using eks-{env}-eks naming fallback", name, err)
		return "", false
	}
	return strings.TrimSpace(out), true
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
