#!/usr/bin/env bash
set -euo pipefail

DATASET="cifar10"
DATA_DIR="./data"
BETA="0.01"
LR="0.01"

AUX_FRAC="0.20"
LABELED_FRAC="0.50"
EPOCHS="200"
POISON_START="0.40"
POISON_INC="0.10"
POISON_STEP="10"
POISON_MAX="0.80"

ARCHS=(resnet18 lenet alexnet vgg16)

for arch in "${ARCHS[@]}"; do
  VICTIM="results/victim_c10_${arch}"
  BASE_OUT="results/backward/${DATASET}/beta_${BETA}/${arch}"

  for i in {2..5}; do
    OUT="${BASE_OUT}/attack${i}"
    echo "=== arch=${arch} attack=${i} -> ${OUT} ==="

    python scripts/attack_backward.py \
      --dataset "${DATASET}" \
      --data "${DATA_DIR}" \
      --arch "${arch}" \
      --victim "${VICTIM}" \
      --aux-frac "${AUX_FRAC}" \
      --labeled-frac "${LABELED_FRAC}" \
      --epochs "${EPOCHS}" \
      --poison-start "${POISON_START}" \
      --poison-inc "${POISON_INC}" \
      --poison-step "${POISON_STEP}" \
      --poison-max "${POISON_MAX}" \
      --beta "${BETA}" \
      --lr "${LR}" \
      --out "${OUT}" \
      --verbose
  done
done