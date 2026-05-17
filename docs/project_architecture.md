# Project Architecture

## 第三阶段目标统一整改

本轮新增并调整以下文件：

- `functions/evaluate_ris_objective.m`：统一 RIS 相位目标评估，支持 `path_gain`、`zf_snr`、`zf_snr_with_condition_penalty`。后续优化器必须明确自己优化哪一个目标。
- `functions/optimize_ris_admm.m`：保留为 `quadratic_admm_approximation`，只优化自己的二次代理目标 `real(v^H Q v)`，不再声称优化真实 path gain 或 ZF-SNR。已加入 `Q/T` 归一化、`rho` 按 `norm(T,2)` 设置，并记录真实 path gain、ZF-SNR 和条件数曲线。
- `functions/optimize_ris_objective_driven.m`：新增工程目标驱动优化器，采用多初值坐标相位搜索，默认优化 `zf_snr`，保证单位模约束，并逐轮记录目标、path gain、SNR、条件数和更新数。
- `main/main_stage3_admm_validation.m`：改为算法诊断脚本，对比 random、quadratic ADMM approximation、objective-driven path_gain、objective-driven zf_snr，不再用单一 “passed” 掩盖结果。

当前诊断结论：后续若目标是复现 SNR 曲线，优先考虑 `optimize_ris_objective_driven(..., "zf_snr", ...)`，而不是 quadratic ADMM proxy。

## 第三阶段整改：ADMM 算法结构修正

本轮将 `functions/optimize_ris_admm.m` 从有限差分相位梯度 surrogate 改为闭式 ADMM 更新结构。当前实现不再使用 finite-difference phase-gradient 作为主体优化逻辑。

当前 `optimize_ris_admm.m` 的方法标识为 `quadratic_admm_approximation`。它使用论文形式的扩展变量：

- `x`: `(Nr+1) x 1`
- `u`: `(Nr+1) x 1`，满足单位模约束
- `mu`: `(Nr+1) x 1`
- `T`: `(Nr+1) x (Nr+1)`

更新公式为：

```text
u = exp(1j * angle(x - mu/rho))
x = (rho*I + T)^(-1) * (rho*u + mu)
mu = mu + rho*(u - x)
```

需要明确的是，当前工程模型采用 `Hrd = Nr x Nr`，而真实路径增益 `||Heff||_F^2` 对相位 `v` 是四次函数，不能直接写成论文中的二次 `x^H T x`。因此当前 `T` 来自 `trace(Heff)` 的 Hermitian 二次代理：

```text
Q = (Hsr*Hsr') .* transpose(Hrd)
Qh = (Q + Q')/2
T(1:Nr,1:Nr) = -Qh
T(Nr+1,Nr+1) = 0
```

新增 `functions/optimize_ris_surrogate.m`，只作为有限差分相位 surrogate 的显式对照，不再作为正式 ADMM。

## Stage 3 Update: RIS Phase ADMM Validation

This stage added or modified:

- `functions/compute_path_gain.m`: executable path-gain objective under the current matrix convention, `gain = ||Heff||_F^2`, with `Heff = Hsr^H * Phi * Hrd * Phi^H * Hsr`.
- `functions/optimize_ris_admm.m`: projected/proximal ADMM surrogate for RIS phase optimization. Because the current `Hrd: Nr x Nr` convention makes `||Heff||_F^2` quartic in `v`, the implementation keeps the ADMM-style `x/u/mu/rho` consensus projection structure but uses finite-difference phase-gradient backtracking for the surrogate `x` step.
- `main/main_stage3_admm_validation.m`: validation script for unit-modulus phases, random-vs-ADMM path gain, random-vs-ADMM ZF SNR, and convergence output.
- `outputs/figures/stage3_admm_convergence.png` and `.fig`: ADMM path-gain convergence curve.
- `outputs/logs/stage3_admm_validation_*.txt`: Stage 3 validation logs.
- `outputs/data/stage3_admm_validation_*.mat`: Stage 3 validation data.

Still not implemented in Stage 3: `optimize_ris_cd.m`, Fig. 3, Fig. 4, Fig. 5, and Fig. 6 reproduction.

## 项目定位

本项目不是单脚本复现，而是面向长期调试和扩展的 MATLAB 科研复现工程。目标是逐步复现论文《RIS辅助MIMO-FMCW雷达的非视距目标参数估计方法》中的 RIS 辅助 MIMO-FMCW 雷达非视距目标参数估计方法和仿真实验。

## 目录结构

```text
RIS_MIMO_FMCW_Reproduction/
├─ main/
├─ config/
├─ functions/
├─ docs/
├─ outputs/
│  ├─ figures/
│  ├─ data/
│  └─ logs/
└─ README.md
```

## 目录职责

`main/` 存放可直接运行的主脚本。每个主脚本对应一个明确实验或图表复现任务，不能把多个无关功能混写到同一个脚本中。

`config/` 集中保存论文参数和仿真参数。后续所有主脚本和函数应优先从 `config/paper_params.m` 读取参数，避免在多个脚本中重复硬编码。

`functions/` 存放可复用 MATLAB 函数。每个函数只负责一个明确功能，例如信道生成、ZF 预编码、RIS 相移优化、SNR 计算、FMCW 回波生成、距离-多普勒处理和绘图风格管理。

`docs/` 是项目管理核心目录。后续每轮代码修改、公式理解、debug、假设调整和实验结果都必须记录到对应文档。

`outputs/figures/` 保存复现图表，例如 `.png`、`.fig`、`.pdf`。

`outputs/data/` 保存中间数据，例如 `.mat` 文件、SNR 曲线数据、距离-多普勒谱矩阵。

`outputs/logs/` 保存脚本运行日志和必要的文本输出。

## 主脚本规划

- `main_reproduce_all.m`：一键运行全部复现实验。后期在各子实验稳定后再完善。
- `main_fig3_snr_vs_Nris.m`：复现图3，比较 ADMM 与 CD 算法的 SNR 随 RIS 反射单元数量变化曲线。
- `main_fig4_snr_vs_power.m`：复现图4，比较不同 RIS 反射单元数量下 ADMM 与 CD 算法的 SNR 随发射功率变化曲线。
- `main_fig5_range_time_3d.m`：复现图5，多目标距离-时间三维幅度谱。
- `main_fig6_range_doppler_maps.m`：复现图6，不同 RIS 反射单元数量下 ADMM 和 CD 算法的距离-多普勒图。

## 函数规划

- `generate_channels.m`：生成 RIS 辅助雷达系统中的 `H_sr` 和 `H_rd` 信道矩阵。
- `design_precoder_zf.m`：根据等效信道设计迫零预编码矩阵 `B`，并进行功率归一化。
- `optimize_ris_admm.m`：根据论文中的 ADMM 更新公式优化 RIS 相移向量 `v` 或相移矩阵 `Phi`。
- `optimize_ris_cd.m`：实现 CD 坐标下降算法，作为 ADMM 的对比基线。
- `compute_snr.m`：根据等效信道、预编码矩阵和噪声功率计算 SNR。
- `generate_fmcw_echo.m`：生成多目标 FMCW 差拍信号，用于距离和速度估计。
- `range_doppler_fft.m`：对 FMCW 回波进行距离 FFT 和多普勒 FFT，生成距离-多普勒谱。
- `plot_utils.m`：统一图表格式，例如坐标轴、字体、图例和保存路径。

## 文档更新规范

1. 每次新增、删除或修改文件后，必须更新 `project_architecture.md`。
2. 每次修改核心公式或变量定义后，必须更新 `paper_formula_notes.md`。
3. 每次新增合理假设后，必须更新 `reproduction_assumptions.md`。
4. 每次运行实验后，必须更新 `experiment_log.md`。
5. 每次遇到错误并修复后，必须更新 `debug_log.md`。
6. 每次完成一个阶段任务后，必须更新 `todo.md`。
7. 不允许在没有说明的情况下大范围重构项目。
8. 不允许把多个功能混写在一个 `main` 脚本里。
9. 不允许为了贴合论文图表而硬编码实验结果。
10. 如果论文细节不足，必须明确标注为“合理复现假设”，不能说成“论文原文如此”。

## 当前阶段

第一轮仅完成工程骨架和文档初版。核心算法、FMCW 回波生成和图3-图6复现均未实现。

## Stage 2 Update: Base Model and Validation

本阶段新增或修改以下文件：

- `config/paper_params.m`：补充线性单位字段和单位换算函数句柄，包括 `dbm2w`、`w2dbm`、`db2pow`、`pow2db`。保留论文参数，并新增阶段性信道几何假设。
- `functions/generate_channels.m`：实现 Rician 信道和路径损耗生成。当前采用 `Hsr: Nr x Nt`、`Hrd: Nr x Nr` 的 RIS 域等效回波信道约定。
- `functions/design_precoder_zf.m`：实现基于 `pinv` 的 ZF 预编码，并按线性发射功率 `txPower_W` 归一化，使 `||B||_F^2 <= P`。
- `functions/compute_snr.m`：实现论文目标形式 `SNR = ||Heff * B||_F^2 / sigma^2`，其中 `sigma^2` 必须为线性功率。
- `main/main_stage2_model_validation.m`：新增第二阶段验证脚本，检查矩阵维度、ZF 功率约束、SNR 随发射功率和噪声功率的单调性，并保存日志和 `.mat` 数据。
- `outputs/logs/stage2_model_validation_*.txt`：保存第二阶段验证日志。
- `outputs/data/stage2_model_validation_*.mat`：保存第二阶段验证数据。

第二阶段仍未实现 `optimize_ris_admm.m`、`optimize_ris_cd.m`、FMCW 回波生成和图3-图6复现。
