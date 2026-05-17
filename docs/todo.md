# TODO

## 第三阶段目标统一整改状态

### 已完成

- [x] 新增 `evaluate_ris_objective.m`，统一计算 `path_gain`、`zf_snr` 和带条件数惩罚的 ZF-SNR。
- [x] 修正 `optimize_ris_admm.m`，明确其只优化 `quadratic_trace_proxy`。
- [x] 对 `Q/T` 做尺度归一化，并按 `norm(T,2)` 设置 `rho`。
- [x] 新增 `optimize_ris_objective_driven.m`，直接优化工程目标。
- [x] 将 `main_stage3_admm_validation.m` 改为算法诊断脚本。
- [x] 输出并保存四类曲线：ADMM 代理目标、真实 path gain、ZF-SNR、条件数。
- [x] 证明 `objective_zf_snr` 相比 random 有明显 SNR 提升。

### 下一步建议

- [ ] 不建议继续围绕 quadratic ADMM proxy 做图3/图4。
- [ ] 若用户接受工程目标优先，应使用 `objective_zf_snr` 作为后续 SNR 曲线主算法。
- [ ] 若仍要论文 ADMM，需要重新定义物理模型，使论文 `T` 矩阵目标和工程目标一致。

## 当前 ADMM 整改状态

### 已完成

- [x] 正视并移除 `optimize_ris_admm.m` 中的 finite-difference phase-gradient 主体逻辑。
- [x] 按论文形式实现 `x/u/mu/rho` 闭式 ADMM 更新。
- [x] 构造 `(Nr+1) x (Nr+1)` 的二次型近似 `T` 矩阵。
- [x] 从 `x(1:Nr)/x(Nr+1)` 恢复 RIS 相位 `v`。
- [x] 新增 `optimize_ris_surrogate.m` 作为有限差分 surrogate 对照。
- [x] 在 `main_stage3_admm_validation.m` 中对比 random、ADMM、surrogate。
- [x] 验证 ADMM 单位模约束、path gain、SNR、primal residual 和 dual residual。

### 暂不进入

- [ ] 暂不实现 CD。
- [ ] 暂不复现图3。
- [ ] 暂不复现图4。

### 需要继续修正

- [ ] 当前 ADMM 是 `quadratic_admm_approximation`，还不是严格论文 ADMM。
- [ ] 需要重新审查论文中 `Hrd`、目标散射矩阵和 `T` 的推导，决定是否调整当前 `Hrd = Nr x Nr` 工程模型。
- [ ] 需要研究如何让 ADMM 优化目标同时服务于 `||Heff||_F^2` 和 ZF 后 SNR，而不是只优化 `trace(Heff)` 的二次代理。

## Stage 3 Status

### Completed

- [x] Confirmed and reused current dimensions: `Hsr: Nr x Nt`, `Hrd: Nr x Nr`, `Phi: Nr x Nr`, `Heff: Nt x Nt`, `B: Nt x Nt`, `v: Nr x 1`.
- [x] Added `functions/compute_path_gain.m`.
- [x] Implemented `functions/optimize_ris_admm.m` as a projected/proximal ADMM surrogate.
- [x] Added and ran `main/main_stage3_admm_validation.m`.
- [x] Verified unit-modulus constraint for `v_admm`.
- [x] Verified ADMM path gain is not lower than random phase.
- [x] Verified ADMM ZF-normalized SNR is not lower than random phase.
- [x] Saved ADMM convergence curve as `.png` and `.fig`.
- [x] Saved Stage 3 validation log and data.
- [x] Updated project documents.

### Not Done

- [ ] `optimize_ris_cd.m` is still not implemented.
- [ ] Fig. 3, Fig. 4, Fig. 5, and Fig. 6 are still not reproduced.
- [ ] The implementation does not yet claim exact reproduction of the paper's closed-form `T`-matrix ADMM.

### Next Suggestions

- [ ] Add MATLAB unittest or small fixed-matrix tests for `compute_path_gain.m` and `optimize_ris_admm.m`.
- [ ] Derive whether the current `Hrd: Nr x Nr` model can produce a valid quadratic ADMM target, or whether the model should be changed before Fig. 3 reproduction.
- [ ] Before Fig. 3, define `N_r` sweep values, Monte Carlo count, and whether to optimize path gain, ZF SNR, or a safeguarded objective.

## 已完成

- [x] 阅读论文 PDF 并提取第一轮复现所需的核心信息。
- [x] 创建 MATLAB 项目目录结构。
- [x] 创建 `main/`、`config/`、`functions/`、`docs/`、`outputs/`。
- [x] 创建项目管理文档初版。
- [x] 创建 MATLAB 占位脚本和函数。

## 进行中

- [ ] 继续核对论文公式与 MATLAB 矩阵维度。

## 待完成

- [ ] 完善 `paper_params.m` 的参数字段和单位换算。
- [ ] 实现并验证 `generate_channels.m`。
- [ ] 实现并验证 `compute_snr.m`。
- [ ] 实现并验证 `design_precoder_zf.m`。
- [ ] 推导并实现 `optimize_ris_admm.m`。
- [ ] 明确 CD 算法细节并实现 `optimize_ris_cd.m`。
- [ ] 复现图3的 SNR vs RIS 单元数量曲线。
- [ ] 复现图4的 SNR vs 发射功率曲线。
- [ ] 实现 FMCW 多目标回波生成。
- [ ] 实现距离-多普勒 FFT。
- [ ] 复现图5多目标距离-时间三维幅度谱。
- [ ] 复现图6不同 RIS 单元数量下的距离-多普勒图。

## 需要人工确认

- [ ] 图3横轴 `N_r` 取值范围。
- [ ] 图4发射功率扫描范围。
- [ ] 是否严格采用三角扫频上下拍频，还是使用标准 chirp 序列 2D FFT 生成距离-多普勒谱。
- [ ] CD 算法是否需要严格复现引用文献[38]的 accelerated coordinate descent。
- [ ] 是否需要复现论文图中的绝对数值，还是先以趋势一致为阶段目标。

## Stage 2 状态

### 已完成

- [x] 完善 `config/paper_params.m`，加入线性功率字段和单位换算函数句柄。
- [x] 实现 `functions/generate_channels.m`，生成 `Hsr` 和 `Hrd` 并返回 `meta`。
- [x] 实现 `functions/compute_snr.m`。
- [x] 实现 `functions/design_precoder_zf.m`。
- [x] 新增并运行 `main/main_stage2_model_validation.m`。
- [x] 验证 `Hsr`、`Hrd`、`Phi`、`Heff`、`B` 维度。
- [x] 验证 ZF 预编码功率约束。
- [x] 验证 SNR 随发射功率增大而增大。
- [x] 验证 SNR 随噪声功率增大而减小。
- [x] 保存第二阶段验证日志和数据。
- [x] 同步更新项目文档。

### 下一阶段建议

- [ ] 增加小型单元测试脚本或 MATLAB unittest，覆盖单位换算、SNR 维度错误、ZF 功率约束。
- [ ] 审查 `Hrd` 的物理建模，决定是否引入目标散射向量和双程标量 RCS。
- [ ] 在实现 ADMM 前，先推导并验证路径增益目标函数与 `T` 矩阵的小尺寸等价性。
- [ ] 明确 Monte Carlo 设置，避免 `generate_channels.m` 在循环中固定生成同一个信道。
