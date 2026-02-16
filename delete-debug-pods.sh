#!/bin/bash

set -e

# Get number of pods from parameter (default to 1)
NUM_PODS=${1:-1}

# Validate input is a positive integer
if ! [[ "$NUM_PODS" =~ ^[0-9]+$ ]] || [ "$NUM_PODS" -lt 1 ]; then
    echo "Error: Please provide a valid positive integer for number of pods"
    echo "Usage: $0 [number_of_pods]"
    exit 1
fi

echo "Deleting $NUM_PODS debug pod(s) from market-data namespace..."
echo ""

# Delete all pods in parallel
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    (
        echo "Deleting $POD_NAME..."
        # Check if pod exists before trying to delete
        if kubectl get pod $POD_NAME -n market-data &>/dev/null; then
            kubectl delete pod $POD_NAME -n market-data
            echo "  ✓ $POD_NAME deleted"
        else
            echo "  ⚠ $POD_NAME not found (skipping)"
        fi
    ) &
done

# Wait for all deletions to complete
wait

echo ""
echo "Done! Deleted $NUM_PODS debug pod(s)."
