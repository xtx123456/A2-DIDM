# PoT (Provenance of Training) for CIFAR-10/100 — ResNet18 / AlexNet

本包实现 **PoT 训练溯源验证**（无需访问训练数据），并提供两种攻击基线：
- **插值攻击（interpolation）**：在 *PoT 初始化的随机模型* 与 *被窃最终模型* 之间按比例线性插值，伪造一条看似合理的训练链（无数据）。
- **规则蒸馏攻击（regulated distillation, same-distribution AUX split）**：把 CIFAR 训练集按相同分布切成 **owner** 与 **attacker AUX** 两部分；其中 **attacker AUX 只有一部分（默认 10%）带标签**。攻击者在无标签 AUX 上做 KD，在带标签 AUX 上做 *KD + 监督 CE*，逐轮保存 checkpoint，伪造训练链（需数据）。

**已支持模型架构**
- `ResNet18CIFAR`
- `AlexNetCIFAR`（适配 CIFAR 输入；推荐分类头使用 1024 维 FC 以提升稳定性）

**关键特性**
- PoT 度量 **P1–P6**：基于 *checkpoint 序列 + 元数据* 计算（无需训练数据）；
- **EMD** 采用等质量样本间的 **1D Wasserstein 精确解**；
- `verify` 随机对照（P6）会**自动按链的架构**（AlexNet/ResNet）构造 PoT 随机模型，保证公平；
- 所有攻击/验证脚本均**架构无关**（通过 `pot_core/arch_utils.py` 统一选择架构与类别数）。

---

## 快速开始（Quickstart）

> 下面命令默认项目根目录为当前工作目录。若使用 `python -m ...` 方式，请确保当前目录在 `PYTHONPATH` 的最前（或在 `scripts/` 下存在 `__init__.py`）。

### 0) 环境准备（可选）
```bash
pip install -r requirements.txt
```

### 1) 训练一条“干净链”
```bash
# ResNet18 + CIFAR-10
python -m scripts.train \
  --dataset cifar10 \
  --data /path/to/datasets/cifar10 \
  --arch resnet18 \
  --out runs/c10_resnet18_clean \
  --epochs 200 --batch-size 128 --lr 0.1 --verbose

# AlexNet + CIFAR-10（建议默认 lr=0.01）
python -m scripts.train \
  --dataset cifar10 \
  --data /path/to/datasets/cifar10 \
  --arch alexnet \
  --out runs/c10_alexnet_clean \
  --epochs 200 --batch-size 128 --lr 0.01 --verbose
```

> 说明：训练脚本会把 `arch` 与 `dataset` 写入 `metadata.json`，供 verify/攻击自动识别；`epoch_0000.pt` 为 **PoT 初始化**快照。

### 2) 插值攻击（无数据）
支持直接传**链目录**（推荐），从中读取最终 checkpoint 与元数据：
```bash
python -m scripts.attack_interp \
  --victim runs/c10_alexnet_clean \
  --out    runs/c10_alexnet_interp_attack \
  --arch   auto \
  --alpha-start 0.0 --alpha-end 1.0 --alpha-step 0.02 \
  --verbose
```
> `--arch auto`：从受害者链的 `metadata.json['arch']` 自动选择（AlexNet/ResNet）。插值仅对**同形状浮点参数**进行，不匹配的键直接采用 final。

### 3) 规则蒸馏攻击（同分布 AUX 切分）
```bash
python -m scripts.attack_distill \
  --victim  runs/c10_alexnet_clean \
  --data    /path/to/datasets/cifar10 \
  --dataset cifar10 \
  --out     runs/c10_alexnet_rd_attack \
  --arch    auto \
  --epochs  100 --batch-size 128 --lr 0.01 --tau 2.0 --lambda-kd 1.0 \
  --labeled-frac 0.10 --lambda-ce 1.0 \
  --verbose
```
- 该脚本会：
  1. 从 victim 链载入 **teacher**（最终权重）；
  2. 构建同架构 **student** 并进行 **PoT 初始化**；
  3. **保存 `epoch_0000.pt`**（真实 PoT init，用于 P3/P4/P6 基线）；
  4. **重新初始化 student** 后开始蒸馏训练（避免“训练起点=已保存的 init”）；
  5. 每个 epoch 保存 `epoch_XXXX.pt` 并更新元信息。

### 4) 验证一条链（P1–P6，严格判定可选）
```bash
python -m scripts.verify \
  --chain runs/c10_alexnet_rd_attack \
  --emd-bins 200 --num-rand 50 --seed 0 \
  --strict
```

### 5) 对比 干净链 vs 攻击链（表 3 风格 + 严格判定）
```bash
python -m scripts.compare \
  --clean  runs/c10_alexnet_clean \
  --attack runs/c10_alexnet_rd_attack \
  --num-rand 20 --strict \
  --csv  runs/compare_alexnet_rd.csv \
  --save runs/compare_alexnet_rd.json
```
> 若终端没有输出，请直接运行 `python scripts/compare.py ...` 或在脚本打印处加 `flush=True`；确保当前目录为项目根，`python -m scripts.compare -h` 能打印帮助。

---

## 目录结构（Repository layout）

```
<repo-root>/
├── requirements.txt
├── README.md
├── pot_core/
│   ├── __init__.py
│   ├── init.py             # PoT GMM 初始化（按 fan-in 的混合模型采样权重）
│   ├── models.py           # ResNet18CIFAR, AlexNetCIFAR（CIFAR 友好）
│   ├── arch_utils.py       # 统一入口：按 metadata/--arch 选择模型类；推断类别数；定位最后一层
│   ├── data.py             # CIFAR10/100 dataloader；owner/AUX 同分布切分
│   ├── metrics.py          # P1–P6 原语：Spearman, L2 权重距离, 1D Wasserstein, P4 PCA 等
│   ├── checkpoints.py      # 保存/加载链：epoch_XXXX.pt + metadata.json
│   └── verify.py           # 组合 P1–P6；P6 随机对照按链的 arch 自动匹配
├── attacks/
│   ├── __init__.py
│   ├── interp.py           # 插值攻击（无数据）；--arch auto；只对同形状浮点参数插值
│   └── distill_same.py     # 规则蒸馏攻击（同分布 AUX），保存 init→reinit→训练全流程
└── scripts/
    ├── train.py            # 统一注册表选择模型；写入 arch/dataset 到元信息
    ├── verify.py           # CLI 包装：调用 pot_core.verify.verify_chain
    ├── compare.py          # CLI 包装：打印表 3；可 --csv / --save；建议加 flush=True
    ├── attack_interp.py    # 薄包装：转发到 attacks.interp.main()
    └── attack_distill.py   # 薄包装：转发到 attacks.distill_same.main()
```

---

## 常见问题（FAQ）

**Q1: `python -m scripts.compare` 没有任何输出？**  
A: 通常是没有正确导入到你的 `scripts` 包（在其他路径被同名包“抢名”）。请：
- 确保当前目录是项目根（能 `ls scripts/compare.py`）；
- 临时用文件路径方式：`python scripts/compare.py ...`；
- 或将项目根加入 `PYTHONPATH`：`PYTHONPATH=$(pwd) python -m scripts.compare -h`。

**Q2: `verify` 的 P6 随机基线为 0/NaN？**  
A: 请确认 `pot_core/verify.py` 已使用 `arch_utils.get_model_cls_from_meta_or_arg(...)`，随机对照与链**同架构**。并保证 `metadata.json['arch']` 为 `AlexNetCIFAR` 或 `ResNet18CIFAR`。

**Q3: AlexNet 的训练总是停在 10% 左右？**  
A: 建议使用 **1024 维 FC 分类头**版本并把 `--lr` 设为 **0.01**，同时保留 loss/梯度的有限性检查与梯度裁剪（见 `scripts/train.py`）。

**Q4: 我想新增模型（如 VGG16）？**  
A: 在 `pot_core/models.py` 实现后，只需在 `pot_core/arch_utils.py` 的注册表 `_REGISTRY/_ALIASES` 登记即可；训练/攻击/验证脚本会自动识别。

---

## 引用（References）

- PoT: Provenance of Training without Training Data (附带 PDF)
- 代码中的实现细节以本仓库为准；学术用途欢迎引用相应论文与本仓库。
