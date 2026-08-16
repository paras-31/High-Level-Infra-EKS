package test

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

// assertLiveInfrastructure validates deployed AWS resources for an environment.
// Does not apply or destroy — read-only health checks after terraform apply.
func assertLiveInfrastructure(t *testing.T, env string) {
	t.Helper()

	region := awsRegion()
	clusterName := expectedClusterName(env)

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	require.NoError(t, err, "load AWS config")

	eksClient := eks.NewFromConfig(cfg)
	ec2Client := ec2.NewFromConfig(cfg)

	t.Logf("Live checks: environment=%s cluster=%s region=%s", env, clusterName, region)
	verifyAWSAccount(t, ctx, cfg)

	cluster, err := eksClient.DescribeCluster(ctx, &eks.DescribeClusterInput{
		Name: aws.String(clusterName),
	})
	if err != nil {
		list, listErr := eksClient.ListClusters(ctx, &eks.ListClustersInput{})
		if listErr == nil && len(list.Clusters) > 0 {
			require.NoError(t, err,
				"cluster %s not found — existing clusters in %s: %v. Run Terraform Apply for %s first",
				clusterName, region, list.Clusters, env)
		}
		require.NoError(t, err,
			"cluster %s not found in %s — run Terraform Apply for %s first", clusterName, region, env)
	}
	require.NotNil(t, cluster.Cluster)

	assert.Equal(t, ekstypes.ClusterStatusActive, cluster.Cluster.Status,
		"cluster %s should be ACTIVE", clusterName)

	vpcID := aws.ToString(cluster.Cluster.ResourcesVpcConfig.VpcId)
	require.NotEmpty(t, vpcID, "cluster VPC ID")

	t.Logf("Cluster status=%s version=%s vpc=%s", cluster.Cluster.Status,
		aws.ToString(cluster.Cluster.Version), vpcID)

	endpoints, err := ec2Client.DescribeVpcEndpoints(ctx, &ec2.DescribeVpcEndpointsInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("vpc-id"), Values: []string{vpcID}},
		},
	})
	require.NoError(t, err, "describe VPC endpoints")

	serviceStates := map[string]ec2types.State{}
	hasS3Gateway := false
	for _, ep := range endpoints.VpcEndpoints {
		svc := aws.ToString(ep.ServiceName)
		short := vpcEndpointShortName(svc)
		serviceStates[short] = ep.State
		t.Logf("VPC endpoint %s type=%s state=%s", short, ep.VpcEndpointType, ep.State)

		if ep.VpcEndpointType == ec2types.VpcEndpointTypeGateway &&
			strings.Contains(svc, ".s3") &&
			ep.State == ec2types.StateAvailable {
			hasS3Gateway = true
		}
	}
	assert.True(t, hasS3Gateway, "S3 gateway VPC endpoint must exist (ECR image layers)")

	for _, svc := range requiredVPCEndpointServices() {
		state, ok := serviceStates[svc]
		assert.True(t, ok, "missing VPC interface endpoint for %s", svc)
		if ok {
			assert.Equal(t, ec2types.StateAvailable, state, "VPC endpoint %s should be available", svc)
		}
	}

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
		t.Logf("Node group %s status=%s instanceTypes=%v", ngName, status, ng.Nodegroup.InstanceTypes)

		if status != ekstypes.NodegroupStatusActive {
			failedNodeGroups = append(failedNodeGroups, ngName)
			for _, issue := range ng.Nodegroup.Health.Issues {
				t.Errorf("node group %s health issue [%s]: %s", ngName, issue.Code, aws.ToString(issue.Message))
			}
		}
		assert.Equal(t, ekstypes.NodegroupStatusActive, status,
			"node group %s must be ACTIVE", ngName)
	}

	for _, addonName := range requiredEKSAddons() {
		addon, err := eksClient.DescribeAddon(ctx, &eks.DescribeAddonInput{
			ClusterName: aws.String(clusterName),
			AddonName:   aws.String(addonName),
		})
		if err != nil {
			t.Errorf("required addon %s: %v", addonName, err)
			continue
		}
		t.Logf("Addon %s status=%s", addonName, addon.Addon.Status)
		assert.Equal(t, ekstypes.AddonStatusActive, addon.Addon.Status,
			"addon %s should be ACTIVE", addonName)
	}

	for _, addonName := range optionalEKSAddonsAfterNodes() {
		addon, err := eksClient.DescribeAddon(ctx, &eks.DescribeAddonInput{
			ClusterName: aws.String(clusterName),
			AddonName:   aws.String(addonName),
		})
		if err != nil {
			t.Logf("Optional addon %s not installed yet: %v", addonName, err)
			continue
		}
		t.Logf("Optional addon %s status=%s", addonName, addon.Addon.Status)
	}

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
		t.Fatalf("node group(s) unhealthy: %s — delete failed node group and re-apply",
			strings.Join(failedNodeGroups, ", "))
	}
}
