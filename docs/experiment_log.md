# Experiment Log

## 2026-05-17 Stage 3 ADMM Validation

- Script: `main/main_stage3_admm_validation.m`
- Random seed: `20251012`
- Dimensions:
  - `Hsr = [16 4]`
  - `Hrd = [16 16]`
  - `vRandom = [16 1]`
  - `vAdmm = [16 1]`
- Unit-modulus max error: `1.1102e-16`
- Path gain:
  - random: `8.9838e-08`
  - ADMM: `1.1582e-07`
  - improvement: `1.1034 dB`
- ZF-normalized SNR:
  - random: `-82.614 dB`
  - ADMM: `-82.3683 dB`
  - improvement: `0.24576 dB`
- ADMM settings:
  - method: `stage3_projected_phase_admm_surrogate`
  - iterations: `50`
  - converged: `false`
  - rho: `1`
  - gradientStep: `0.005`
- Output log: `outputs/logs/stage3_admm_validation_20260517_161538.txt`
- Output data: `outputs/data/stage3_admm_validation_20260517_161538.mat`
- Output figures:
  - `outputs/figures/stage3_admm_convergence.png`
  - `outputs/figures/stage3_admm_convergence.fig`
- Acceptance result: script ran successfully; unit-modulus constraint passed; ADMM path gain and ZF SNR were both not lower than the random phase baseline; convergence figures were saved.

## 2026-05-17 Stage 3 Final Verification Run

- Script: `main/main_stage3_admm_validation.m`
- Purpose: final verification after Code Analyzer cleanup.
- Random seed: `20251012`
- Unit-modulus max error: `1.1102e-16`
- Random path gain: `8.9838e-08`
- ADMM path gain: `1.1582e-07`
- Gain improvement: `1.1034 dB`
- Random SNR: `-82.614 dB`
- ADMM SNR: `-82.3683 dB`
- SNR improvement: `0.24576 dB`
- ADMM iterations: `50`
- ADMM converged: `false`
- Output log: `outputs/logs/stage3_admm_validation_20260517_161902.txt`
- Output data: `outputs/data/stage3_admm_validation_20260517_161902.mat`
- Output figures:
  - `outputs/figures/stage3_admm_convergence.png`
  - `outputs/figures/stage3_admm_convergence.fig`
- Acceptance result: passed.

本文件记录每次实验运行结果。每次运行 `main/` 下脚本后必须追加记录。

## 记录模板

```text
日期：
运行脚本：
Git/文件状态：
参数设置：
输出数据：
输出图表：
运行结果摘要：
是否符合论文趋势：
异常现象：
后续动作：
```

## 2026-05-17 工程初始化

- 运行脚本：无。
- 结果：仅创建项目结构和文档占位，未运行仿真实验。
- 输出：无实验图表或数据。

## 2026-05-17 Stage 2 Model Validation

- 运行脚本：`main/main_stage2_model_validation.m`
- 参数入口：`config/paper_params.m`
- 随机种子：`20251009`
- 采用维度：
  - `Hsr = [16 4]`
  - `Hrd = [16 16]`
  - `Phi = [16 16]`
  - `Heff = [4 4]`
  - `B = [4 4]`
- ZF 结果：
  - raw power: `7.302333e+08 W`
  - normalized power: `1.000000e-02 W`
  - relative error: `6.991189e-16`
- 名义 SNR：
  - linear: `5.477701e-09`
  - dB: `-82.614017 dB`
- 发射功率扫描：
  - power dBm: `[0 5 10 15 20]`
  - SNR dB: `[-92.614 -87.614 -82.614 -77.614 -72.614]`
  - 验收结果：SNR 随发射功率增大而增大。
- 噪声功率扫描：
  - noise dBm: `[-20 -10 0 10 20]`
  - SNR dB: `[-52.614 -62.614 -72.614 -82.614 -92.614]`
  - 验收结果：SNR 随噪声功率增大而减小。
- 输出日志：`outputs/logs/stage2_model_validation_20260517_153924.txt`
- 输出数据：`outputs/data/stage2_model_validation_20260517_153924.mat`
- 备注：当前绝对 SNR 很低，原因可能是阶段性路径损耗假设和 `noisePower_dBm = 10` 共同导致。第二阶段只将其作为模型一致性验证，不作为论文图3或图4数值复现结论。

## 2026-05-17 Stage 2 Final Verification Run

- 运行脚本：`main/main_stage2_model_validation.m`
- 运行目的：文档同步后进行最终验收验证。
- 结果摘要：
  - `Hsr = [16 4]`
  - `Hrd = [16 16]`
  - `Phi = [16 16]`
  - `Heff = [4 4]`
  - `B = [4 4]`
  - ZF normalized power: `0.01 W`
  - ZF relative error: `6.9912e-16`
  - nominal SNR: `-82.614 dB`
  - SNR vs power dB: `[-92.614 -87.614 -82.614 -77.614 -72.614]`
  - SNR vs noise dB: `[-52.614 -62.614 -72.614 -82.614 -92.614]`
- 输出日志：`outputs/logs/stage2_model_validation_20260517_154101.txt`
- 输出数据：`outputs/data/stage2_model_validation_20260517_154101.mat`
- 验收结论：维度、功率约束、发射功率单调性、噪声功率单调性均通过。
