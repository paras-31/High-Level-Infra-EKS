package test

import "testing"

func TestIsClusterNameOutput(t *testing.T) {
	t.Parallel()

	valid := []string{"eks-dev-eks", "eks-prod-eks", "eks-staging-eks"}
	for _, v := range valid {
		if !isClusterNameOutput(v) {
			t.Errorf("expected valid cluster name: %q", v)
		}
	}

	invalid := []string{
		"",
		"Warning: No outputs found",
		"eks-dev",
		"not-a-cluster",
	}
	for _, v := range invalid {
		if isClusterNameOutput(v) {
			t.Errorf("expected invalid cluster name: %q", v)
		}
	}
}
