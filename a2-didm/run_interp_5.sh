#!/usr/bin/env bash
set -euo pipefail

PYTHON=${PYTHON:-python}

# 固定参数
VICTIM="/root/autodl-tmp/attack-test/results/victim_c10_alexnet"
ARCH="alexnet"

# 输出父目录（按你之前风格）
OUT_BASE="/root/autodl-tmp/attack-test/results/attack_alexnet_c10"

# 你说的 lambda=0.005，这里用 alpha 表示插值系数
LAMBDA=0.005

mkdir -p "$OUT_BASE"

run_one () {
  local attack_id="$1"
  local out_dir="${OUT_BASE}/attack${attack_id}"

  echo "============================================================"
  echo "[Interp Attack ${attack_id}] lambda(alpha)=${LAMBDA}"
  echo "out: ${out_dir}"
  echo "============================================================"

  mkdir -p "$out_dir"

  $PYTHON scripts/attack_interp.py \
    --victim "$VICTIM" \
    --out "$out_dir" \
    --arch "$ARCH" \
    --alpha-start 0.0 \
    --alpha-end 1.0 \
    --alpha-step 0.005 \
    --verbose
}

# 5 次：attack22~attack26
for id in 22 23 24 25 26; do
  run_one "$id"
done