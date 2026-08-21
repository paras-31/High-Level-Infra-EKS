package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestTerraform is the main Terratest entry point (Pattern Catalog style).
//
// CI / local env vars:
//   - TEST_ENVIRONMENT  — dev | staging | prod (required)
//   - TERRATEST_SKIP_LIVE — set "true" to run terraform validate only (PR/push)
//   - AWS_REGION          — default ap-south-1
//   - TEST_AWS_ACCOUNT_ID — default 174765206872
//
// Unlike small module examples (e.g. secretsmanager), full EKS apply+destroy is
// not run here — it takes 30–45 min and is handled by terraform-apply.yml.
// Live checks validate already-deployed infrastructure read-only.
func TestTerraform(t *testing.T) {
	env := os.Getenv("TEST_ENVIRONMENT")
	if env == "" {
		t.Fatal("TEST_ENVIRONMENT is required (dev, staging, or prod)")
	}

	t.Run(env, func(t *testing.T) {
		opts := terraform.WithDefaultRetryableErrors(t, terraformOptions(env))

		terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
		terraform.Validate(t, opts)

		if skipLiveChecks() {
			t.Log("Skipping live AWS checks (TERRATEST_SKIP_LIVE=true)")
			return
		}

		assertLiveInfrastructure(t, env)
	})
}

// TestTerraformAllEnvironments runs static validate for every environment in parallel.
// Local: go test ./tests/... -run TestTerraformAllEnvironments -v
func TestTerraformAllEnvironments(t *testing.T) {
	for _, env := range allEnvironments {
		env := env
		t.Run(env, func(t *testing.T) {
			t.Parallel()

			opts := terraform.WithDefaultRetryableErrors(t, terraformOptions(env))
			terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
			terraform.Validate(t, opts)
		})
	}
}
