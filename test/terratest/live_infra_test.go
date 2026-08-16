package terratest

import (
	"context"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/eks"
	ekstypes "github.com/aws/aws-sdk-go-v2/service/eks/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Live validation against deployed infrastructure — does NOT apply or destroy.
// Uses AWS API only (no terraform output — empty/partial state is common).
func TestLiveInfrastructureHealth(t *testing.T) {
	env := testEnvironment()
	region := awsRegion()
	clusterName := expectedClusterName(env)

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")

	eksClient := eks.NewFromConfig(cfg)
	ec2Client := ec2.NewFromConfig(cfg)

	t.Logf("Validating live infrastructure for environment=%s cluster=%s region=%s", env, clusterName, region)

	verifyAWSAccount(t, ctx, cfg)

	// ── EKS cluster ─────────────────────────────────────────────────────────
	cluster, err := eksClient.DescribeCluster(ctx, &eks.DescribeClusterInput{
		Name: aws.String(clusterName),
	})
	require.NoError(t, err, "describe EKS cluster — cluster must exist in AWS")
	require.NotNil(t, cluster.Cluster)

	assert.Equal(t, ekstypes.ClusterStatusActive, cluster.Cluster.Status,
		"cluster %s should be ACTIVE", clusterName)

	vpcID := aws.ToString(cluster.Cluster.ResourcesVpcConfig.VpcId)
	require.NotEmpty(t, vpcID, "cluster VPC ID")

	t.Logf("Cluster status=%s version=%s vpc=%s publicAPI=%v",
		cluster.Cluster.Status,
		aws.ToString(cluster.Cluster.Version),
		vpcID,
		cluster.Cluster.ResourcesVpcConfig.EndpointPublicAccess,
	)

	// ── VPC endpoints required for private node ECR pulls ───────────────────
	endpoints, err := ec2Client.DescribeVpcEndpoints(ctx, &ec2.DescribeVpcEndpointsInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("vpc-id"), Values: []string{vpcID}},
		},
	})
	require.NoError(t, err, "describe VPC endpoints")

	serviceStates := map[string]ec2types.State{}
	for _, ep := range endpoints.VpcEndpoints {
		svc := aws.ToString(ep.ServiceName)
		short := vpcEndpointShortName(svc)
		serviceStates[short] = ep.State
		t.Logf("VPC endpoint %s type=%s state=%s", short, ep.VpcEndpointType, ep.State)
	}

	hasS3Gateway := false
	for _, ep := range endpoints.VpcEndpoints {
		if ep.VpcEndpointType == ec2types.VpcEndpointTypeGateway &&
			strings.Contains(aws.ToString(ep.ServiceName), ".s3") &&
			ep.State == ec2types.StateAvailable {
			hasS3Gateway = true
		}
	}
	assert.True(t, hasS3Gateway, "S3 gateway VPC endpoint must exist and be available (ECR image layers)")

	for _, svc := range requiredVPCEndpointServices() {
		state, ok := serviceStates[svc]
		assert.True(t, ok, "missing VPC interface endpoint for %s — nodes cannot reach AWS APIs privately", svc)
		if ok {
			assert.Equal(t, ec2types.StateAvailable, state, "VPC endpoint %s should be available", svc)
		}
	}

	// ── Node groups ─────────────────────────────────────────────────────────
	ngList, err := eksClient.ListNodegroups(ctx, &eks.ListNodegroupsInput{
		ClusterName: aws.String(clusterName),
	})
	require.NoError(t, err, "list node groups")

	require.NotEmpty(t, ngList.Nodegroups, "expected at least one managed node group")

	var failedNodeGroups []string
	for _, ngName := range ngList.Nodegroups {
		ng, err := eksClient.DescribeNodegroup(ctx, &eks.DescribeNodegroupInput{
			ClusterName:   aws.String(clusterName),
			NodegroupName: aws.String(ngName),
		})
		require.NoError(t, err, "describe node group %s", ngName)

		status := ng.Nodegroup.Status
		t.Logf("Node group %s status=%s instanceTypes=%v",
			ngName, status, ng.Nodegroup.InstanceTypes)

		if status != ekstypes.NodegroupStatusActive {
			failedNodeGroups = append(failedNodeGroups, ngName)
			for _, issue := range ng.Nodegroup.Health.Issues {
				t.Errorf("node group %s health issue [%s]: %s", ngName, issue.Code, aws.ToString(issue.Message))
			}
		}

		assert.Equal(t, ekstypes.NodegroupStatusActive, status,
			"node group %s must be ACTIVE (CREATE_FAILED usually means unhealthy nodes / ECR network)", ngName)
	}

	// ── EKS managed add-ons ─────────────────────────────────────────────────
	for _, addonName := range requiredEKSAddons() {
		addon, err := eksClient.DescribeAddon(ctx, &eks.DescribeAddonInput{
			ClusterName: aws.String(clusterName),
			AddonName:   aws.String(addonName),
		})
		if err != nil {
			t.Errorf("required addon %s: %v", addonName, err)
			continue
		}

		t.Logf("Addon %s status=%s version=%s", addonName, addon.Addon.Status, aws.ToString(addon.Addon.AddonVersion))

		if addon.Addon.Status != ekstypes.AddonStatusActive {
			for _, issue := range addon.Addon.Health.Issues {
				t.Errorf("addon %s issue [%s]: %s", addonName, issue.Code, aws.ToString(issue.Message))
			}
		}

		assert.Equal(t, ekstypes.AddonStatusActive, addon.Addon.Status,
			"addon %s should be ACTIVE; DEGRADED + ImagePullBackOff indicates ECR/VPC endpoint problem", addonName)
	}

	for _, addonName := range optionalEKSAddonsAfterNodes() {
		addon, err := eksClient.DescribeAddon(ctx, &eks.DescribeAddonInput{
			ClusterName: aws.String(clusterName),
			AddonName:   aws.String(addonName),
		})
		if err != nil {
			t.Logf("Optional addon %s not installed yet (expected until node groups are ACTIVE): %v", addonName, err)
			continue
		}
		t.Logf("Optional addon %s status=%s", addonName, addon.Addon.Status)
	}

	// ── EC2 worker instances ────────────────────────────────────────────────
	instances, err := ec2Client.DescribeInstances(ctx, &ec2.DescribeInstancesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("tag:eks:cluster-name"), Values: []string{clusterName}},
			{Name: aws.String("instance-state-name"), Values: []string{"pending", "running"}},
		},
	})
	require.NoError(t, err, "describe worker EC2 instances")

	running := 0
	for _, res := range instances.Reservations {
		running += len(res.Instances)
	}
	t.Logf("Worker EC2 instances (pending+running): %d", running)
	assert.Greater(t, running, 0, "expected running worker EC2 instances for cluster %s", clusterName)

	if len(failedNodeGroups) > 0 {
		t.Fatalf("node group(s) unhealthy: %s — fix network/ECR endpoints, delete failed node group, re-apply (do not full destroy)",
			strings.Join(failedNodeGroups, ", "))
	}
}
