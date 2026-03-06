#!/usr/bin/env bash
set -euo pipefail

PYTHON=${PYTHON:-python}

# 固定参数
VICTIM="/root/autodl-tmp/attack-test/results/victim_c10_alexnet"
DATA="/root/autodl-tmp/attack-test/data"                      # 按你的实际 CIFAR 根目录改；如 /root/autodl-tmp/attack-test/data
DATASET="cifar10"
ARCH="alexnet"

OUT_BASE="/root/autodl-tmp/attack-test/results/attack_alexnet_c10"

# 其他可选固定超参（按需改）
EPOCHS=200
BATCH_SIZE=256
WORKERS=4
SPLIT_SEED=0
TAU=4.0
TAU_END=4.0
LAMBDA_KD=1.0
LAMBDA_END=1.0
LAMBDA_CE=1.0
LAMBDA_CE_END=1.0
LR=0.05
WEIGHT_DECAY=5e-4
VAL_HOLDOUT=2000

mkdir -p "$OUT_BASE"

run_one () {
  local attack_id="$1"
  local aux_frac="$2"
  local labeled_frac="$3"
  local out_dir="${OUT_BASE}/attack${attack_id}"

  echo "============================================================"
  echo "[Attack ${attack_id}] aux-frac=${aux_frac}, labeled-frac=${labeled_frac}"
  echo "out: ${out_dir}"
  echo "============================================================"

  mkdir -p "$out_dir"

  $PYTHON scripts/attack_distill.py \
    --victim "$VICTIM" \
    --data "$DATA" \
    --dataset "$DATASET" \
    --out "$out_dir" \
    --arch "$ARCH" \
    --epochs "$EPOCHS" \
    --batch-size "$BATCH_SIZE" \
    --workers "$WORKERS" \
    --aux-frac "$aux_frac" \
    --split-seed "$SPLIT_SEED" \
    --labeled-frac "$labeled_frac" \
    --tau "$TAU" \
    --tau-end "$TAU_END" \
    --lambda-kd "$LAMBDA_KD" \
    --lambda-end "$LAMBDA_END" \
    --lambda-ce "$LAMBDA_CE" \
    --lambda-ce-end "$LAMBDA_CE_END" \
    --lr "$LR" \
    --weight-decay "$WEIGHT_DECAY" \
    --val-holdout "$VAL_HOLDOUT" \
    --verbose
}

# # 前 5 次：attack12~attack16
# for id in 12 13 14 15 16; do
#   run_one "$id" 0.2 0.5
# done

# 后 5 次：attack17~attack22（注意这里是 6 次；若你只要 5 次应到 attack21）
for id in 17 18 19 20 21; do
  run_one "$id" 0.2 0.9
done