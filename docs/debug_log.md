# Debug Log

## 2026-05-17 Stage 3 Validation Issues

### Missing path-gain function

- Script: `main/main_stage3_admm_validation.m`
- Symptom: first validation run failed because `compute_path_gain` was undefined.
- Root cause: validation was written before the production function, as intended.
- Fix: added `functions/compute_path_gain.m`.

### Path gain improvement can reduce ZF SNR

- Functions: `optimize_ris_admm.m`, `design_precoder_zf.m`, `compute_snr.m`
- Symptom: with `gradientStep = 0.25`, path gain increased from `8.9838e-08` to `5.2076e-07`, but ZF-normalized SNR dropped from `-82.614 dB` to `-83.5887 dB`.
- Evidence: `pinv(Heff)` raw power increased from `7.3023e+08 W` to `9.1396e+08 W`, and condition number increased from about `5.24` to about `19.41`.
- Root cause: maximizing `||Heff||_F^2` alone does not guarantee better ZF-normalized SNR; aggressive phase steps can make `Heff` more ill-conditioned.
- Fix: use conservative validation settings, `gradientStep = 0.005` and `maxIter = 50`.
- Verification: rerun improved path gain by `1.1034 dB` and ZF-normalized SNR by `0.24576 dB`.

本文件记录每次 bug、错误信息、定位过程、修复方案和遗留问题。

## 记录模板

```text
日期：
相关脚本/函数：
错误信息：
复现步骤：
定位过程：
根因判断：
修复方案：
验证方式：
遗留问题：
```

## 2026-05-17 工程初始化

- 当前未进行算法实现，暂无运行错误。
- 已识别后续高风险 debug 点：
  - 接收信号模型的矩阵维度。
  - `H_rd` 的物理含义和维度。
  - ADMM 扩展变量 `x`、`u`、`mu` 的维度。
  - ZF 伪逆在病态信道下的稳定性。
  - FMCW 三角扫频与标准距离-多普勒 FFT 的对应关系。

## 2026-05-17 Stage 2 Validation Issues

### Expected failing validation before implementation

- 相关脚本：`main/main_stage2_model_validation.m`
- 现象：首次运行失败在 `generate_channels.m`，错误为 `generate_channels is a placeholder`。
- 判断：这是 validation-first 的预期失败，证明新验证脚本能够捕获基础函数未实现状态。
- 处理：实现 `paper_params.m`、`generate_channels.m`、`design_precoder_zf.m`、`compute_snr.m` 后重新运行。

### Empty diary log

- 相关脚本：`main/main_stage2_model_validation.m`
- 现象：MATLAB 控制台显示验证通过，但 `diary` 生成的成功日志文件为空。
- 根因判断：当前 MCP MATLAB 执行环境下 `diary` 捕获不可靠。
- 修复方案：移除对 `diary` 的依赖，改为在验证结束后显式构造 `logLines` 并用 `writelines(logLines, logPath)` 写入日志。
- 验证：重新运行后 `outputs/logs/stage2_model_validation_20260517_153924.txt` 包含完整维度、ZF 和 SNR 验证结果。
