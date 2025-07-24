# Helm Overrides

This doc contains various customizations that are supported within your Helm overrides file for your TFE deployment.

## Scaling TFE pods

To manage the number of pods running within your TFE deployment, set the value of the `replicaCount` key accordingly.

```yaml
replicaCount: 3
```

## Service (type `LoadBalancer`)

### Internal

By default, the `module_generated_helm_overrides.yaml` contains a configuration with a load balancing scheme of `internal`.

```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal" 
    service.beta.kubernetes.io/aws-load-balancer-subnets: "<list, of, lb_subnet_ids>"
    service.beta.kubernetes.io/aws-load-balancer-security-groups: "<lb-security-group-id>"
  type: LoadBalancer
  port: 443
```

### External

If you want to configure an `internet-facing` (external) load balancer, the set the `service.beta.kubernetes.io/aws-load-balancer-scheme` annotation accordingly:

```yaml
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb-ip"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-subnets: "<list, of, lb_subnet_ids>"
    service.beta.kubernetes.io/aws-load-balancer-security-groups: "<lb-security-group-id>"
  type: LoadBalancer
  port: 443
```

## Custom agents

By default, the TFE Helm chart creates a separate namespace for _agents_, which are responsible for actually executing the Terraform runs within your TFE system. If you would like to customize the agents configuration, you can use the `agentWorkerPodTemplate`.

Example:

```yaml
agentWorkerPodTemplate:
  spec:
    nodeSelector:
        eks.amazonaws.com/nodegroup: <tfe-eks-private-nodes-agents>
    containers:
      - name: tfc-agent
        image: <namespace>/<custom-tfc-agent>:<1.0>
        resources:
          requests:
            memory: 750Mi
```
