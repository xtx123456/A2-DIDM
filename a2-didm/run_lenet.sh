#!/usr/bin/env bash
set -euo pipefail

BASE_OUT="results/backward/cifar10/beta_0.001/lenet"

for i in {2..5}; do
  OUT="${BASE_OUT}/attack${i}"
  echo "Running attack${i} -> ${OUT}"

  python scripts/attack_backward.py \
    --dataset cifar10 \
    --data ./data \
    --arch lenet \
    --victim results/victim_c10_lenet \
    --aux-frac 0.20 \
    --labeled-frac 0.50 \
    --epochs 200 \
    --poison-start 0.40 \
    --poison-inc 0.10 \
    --poison-step 10 \
    --poison-max 0.80 \
    --beta 0.001 \
    --lr 0.01 \
    --out "${OUT}" \
    --verbose
done