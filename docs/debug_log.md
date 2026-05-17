# Debug Log

## 2026-05-17 目标统一整改中的问题

### ADMM 数值发散

- 现象：`rhoScale = 0.2` 时，`x` 和 `mu` 范数快速指数增长，后续 `Heff` 出现 NaN/Inf。
- 根因：`Q/T` 归一化后，`rho` 仍然相对过小，`rho*I + T` 虽可逆但动力学不稳定。
- 修复：默认 `rhoScale` 改为 `2`，即按 `2*norm(T,2)` 量级设置 `rho`。
- 验证：最终 `rho = 0.97179`、`normT = 0.4859`，ADMM 收敛标志为 `true`，primal residual `1.0051e-07`，dual residual `4.047e-07`。

### 代理目标与工程目标冲突

- 现象：quadratic ADMM 和 path_gain optimizer 都会提高 path gain，但降低 ZF-SNR。
- 根因：ZF-SNR 受 `pinv(Heff)` 和条件数影响，`||Heff||_F^2` 不是充分目标。
- 处理：新增 `evaluate_ris_objective.m` 和 `optimize_ris_objective_driven.m`，直接优化 `zf_snr`。

## 2026-05-17 第三阶段 ADMM 整改问题记录

### 问题 1：原 `optimize_ris_admm.m` 不是严格 ADMM

- 现象：原实现使用 finite-difference phase-gradient surrogate，并令 `x = candidateU`，随后 `u = project(x - mu/rho)`。
- 根因：`x` 已经接近单位模，导致 `u` 近似等于 `x`，primal residual 接近 0，`mu` 基本不起作用。
- 修复：删除该主体逻辑，改为闭式 ADMM：
  - `u = exp(1j * angle(x - mu/rho))`
  - `x = (rho*I + T)^(-1) * (rho*u + mu)`
  - `mu = mu + rho*(u - x)`

### 问题 2：论文 `T` 矩阵无法直接等价到当前 `||Heff||_F^2`

- 现象：当前 `Heff = Hsr^H * diag(v) * Hrd * diag(v)^H * Hsr`，`||Heff||_F^2` 是四次目标。
- 根因：论文 ADMM 的闭式 `x` 更新依赖二次型 `x^H T x`；当前真实 path gain 不是二次型。
- 修复：构造维度自洽的二次代理：
  - `Q = (Hsr*Hsr^H) .* transpose(Hrd)`
  - `Qh = (Q + Q^H)/2`
  - `T(1:Nr,1:Nr) = -Qh`
  - `T(Nr+1,Nr+1) = 0`
- 标注：该实现为 `quadratic_admm_approximation`，不是严格论文 ADMM。

### 问题 3：surrogate 优于 ADMM 近似

- 现象：最终验证中 surrogate path gain 和 SNR 均高于 quadratic ADMM approximation。
- 判断：如实保留该结果，不强行调参或放大 ADMM 输出。
- 后续：若要复现论文图3/图4，需要继续推导更接近论文物理模型的 `T`，或重新定义与 ZF SNR 一致的优化目标。

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
