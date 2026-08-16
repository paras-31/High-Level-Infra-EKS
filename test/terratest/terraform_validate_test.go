package terratest

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// Static checks — no AWS credentials required beyond module checkout for init.
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

			terraform.InitAndValidate(t, opts)
		})
	}
}
