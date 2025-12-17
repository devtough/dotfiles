#!/usr/bin/env bash
# Kubernetes context script for tmux status bar

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "no kubectl"
  exit 0
fi

# Get current context (with timeout to avoid hangs)
context=$(timeout 2 kubectl config current-context 2>/dev/null)

if [ -z "$context" ]; then
  echo "no ctx"
  exit 0
fi

# Get namespace for current context
namespace=$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}' 2>/dev/null)

# Simplify EKS ARN to just cluster name
if [[ "$context" =~ ^arn:aws:eks: ]]; then
  context=${context##*/}
fi

# Build output
if [ -n "$namespace" ]; then
  echo "${context}/${namespace}"
else
  echo "${context}"
fi
