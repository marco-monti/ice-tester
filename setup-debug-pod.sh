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

echo "Creating $NUM_PODS debug pod(s) in market-data namespace..."

# Loop through and create each pod
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    echo ""
    echo "========================================"
    echo "Setting up $POD_NAME ($i/$NUM_PODS)"
    echo "========================================"

    echo "Creating pod $POD_NAME..."
    sed "s/name: debug-pod/name: $POD_NAME/" debug-pod.yaml | kubectl apply -f -

    echo "Waiting for pod to be created..."
    sleep 5
done

# Wait for all pods to be ready
echo ""
echo "Waiting for all pods to be ready (this may take 2-3 minutes while packages install)..."
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    echo "Waiting for $POD_NAME..."
    kubectl wait --for=condition=Ready pod/$POD_NAME -n market-data --timeout=300s
done

# Wait for package installation to complete (unzip availability)
echo ""
echo "Waiting for package installation to complete in all pods..."
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    echo "Checking $POD_NAME..."
    for attempt in {1..60}; do
        if kubectl exec -n market-data $POD_NAME -- which unzip &>/dev/null; then
            echo "  ✓ $POD_NAME ready"
            break
        fi
        if [ $attempt -eq 60 ]; then
            echo "  ⚠ $POD_NAME: Timeout waiting for unzip to be available"
            exit 1
        fi
        sleep 2
    done
done
echo "All packages installed!"

# Copy files to all pods in parallel
echo ""
echo "Copying cfapi-java zip files to all pods in parallel..."
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    (
        echo "  Copying to $POD_NAME..."
        kubectl cp cfapi-java-1.7.0.6-GA.zip market-data/$POD_NAME:/tmp/cfapi-java-1.7.0.6-GA.zip
        echo "  ✓ $POD_NAME copy complete"
    ) &
done
wait
echo "All zip files copied!"

# Unzip files in all pods in parallel
echo ""
echo "Unzipping files in all pods in parallel..."
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    (
        echo "  Unzipping in $POD_NAME..."
        kubectl exec -n market-data $POD_NAME -- unzip -q /tmp/cfapi-java-1.7.0.6-GA.zip -d /tmp/
        echo "  ✓ $POD_NAME unzip complete"
    ) &
done
wait
echo "All files unzipped!"

# Set permissions and validate in parallel
echo ""
echo "Setting permissions and validating in all pods in parallel..."
for i in $(seq 1 $NUM_PODS); do
    POD_NAME="debug-pod-$i"
    (
        echo "  Setting up $POD_NAME..."
        kubectl exec -n market-data $POD_NAME -- find /tmp -type f -name "*.sh" -exec chmod +x {} \;

        NON_EXEC=$(kubectl exec -n market-data $POD_NAME -- find /tmp -type f -name "*.sh" ! -executable 2>/dev/null || true)
        if [ -n "$NON_EXEC" ]; then
            echo "  ⚠ $POD_NAME: Some .sh files are not executable:"
            echo "$NON_EXEC"
            exit 1
        fi

        kubectl exec -n market-data $POD_NAME -- bash -c 'echo "ENUM_SRC_ID=593  COMMAND=QuerySnapAndSubscribeWildCard" > /tmp/cmd.txt'
        echo "  ✓ $POD_NAME setup complete"
    ) &
done
wait
echo "All pods configured!"

echo ""
echo "========================================"
echo "Done! All $NUM_PODS pod(s) ready."
echo "========================================"
echo ""
echo "To access the pods, run:"
for i in $(seq 1 $NUM_PODS); do
    echo "  kubectl exec -it debug-pod-$i -n market-data -- /bin/bash"
done
echo ""
echo "To verify Java installation:"
for i in $(seq 1 $NUM_PODS); do
    echo "  kubectl exec -n market-data debug-pod-$i -- java -version"
done
