# Debug Pod Scripts

ICE connection troubleshooting scripts for testing market data connectivity across multiple pods.

## Create Pods
`./setup-debug-pod.sh [N]` - Creates N debug pods (default: 1)

## Delete Pods
`./delete-debug-pods.sh [N]` - Deletes N debug pods (default: 1)

## Run ICE Client Test

**Development:**
`kubectl exec -n market-data debug-pod-1 -- bash -c "cd /tmp && ./clienttest.sh -u TRRep_WT_Extra -p pwd -P 156.48.15.1 7022 cmd.txt"`

**Staging:**
`kubectl exec -n market-data debug-pod-1 -- bash -c "cd /tmp && ./clienttest.sh -u TRRepWTL2Prod2 -p pwd -P 156.48.15.1 7022 cmd.txt"`
