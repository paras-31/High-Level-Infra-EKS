package terratest

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Dev-only static validate — no remote state/backend required.
func TestTerraformValidateDev(t *testing.T) {
	opts := &terraform.Options{
		TerraformDir: environmentDir("dev"),
		NoColor:      true,
	}

	terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
	terraform.Validate(t, opts)
}

// Optional: validate all environments locally.
//   go test ./terratest/... -run TestTerraformValidateEnvironments
func TestTerraformValidateEnvironments(t *testing.T) {
	t.Parallel()

	for _, env := range []string{"dev", "staging", "prod"} {
		env := env
		t.Run(env, func(t *testing.T) {
			t.Parallel()
			opts := &terraform.Options{
				TerraformDir: environmentDir(env),
				NoColor:      true,
			}
			terraform.RunTerraformCommand(t, opts, "init", "-backend=false", "-input=false")
			terraform.Validate(t, opts)
		})
	}
}
