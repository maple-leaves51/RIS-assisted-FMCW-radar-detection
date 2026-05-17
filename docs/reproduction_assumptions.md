# Reproduction Assumptions

## 第三阶段整改后的合理假设

1. 当前未能严格实现论文原始 `T` 矩阵。
   - 原因不是代码偷懒，而是当前工程采用 `Hrd = Nr x Nr` 后，真实目标 `||Heff||_F^2` 是四次目标。
   - 论文中的 `T` 矩阵推导更接近二次型路径增益表达，和当前 `||Heff||_F^2` 目标不完全一致。

2. 当前正式 ADMM 是 `quadratic_admm_approximation`。
   - 它使用论文形式的 `x/u/mu/rho` 和闭式 `x` 更新。
   - `T` 的维度是 `(Nr+1) x (Nr+1)`。
   - `T` 来自 `trace(Heff)` 的 Hermitian 二次代理，而不是来自 `||Heff||_F^2` 的精确等价变换。

3. 当前 `optimize_ris_admm.m` 不使用有限差分相位梯度。
   - `info.usesFiniteDifferenceGradient = false`。
   - 原有限差分方法保留为 `optimize_ris_surrogate.m`，只用于对照。

4. ADMM 的 residual 有意义但尚未收敛。
   - 最终验证中 primal residual 为 `3.6459e-09`。
   - dual residual 为 `9.6119e-05`。
   - `converged = false`，说明当前二次代理 ADMM 结构可运行，但收敛准则和目标一致性仍需继续修正。

## Stage 3 Assumptions Added

1. `compute_path_gain.m` uses `gain = ||Heff||_F^2`.
   - This is the executable objective under `Hsr: Nr x Nt` and `Hrd: Nr x Nr`.
   - It is not presented as the exact paper `T`-matrix quadratic objective.

2. `optimize_ris_admm.m` is a projected/proximal ADMM surrogate.
   - It keeps the `x/u/mu/rho` consensus-projection structure.
   - The `x` step uses finite-difference phase-gradient backtracking.
   - The closed-form paper update `(rho I + T)^(-1)(rho u + mu)` is not forced, because the current objective is quartic under the Stage-2 `Hrd` convention.

3. Stage 3 validation checks both path gain and ZF-normalized SNR.
   - Actual debugging showed that aggressive path-gain ascent can reduce ZF SNR by making `Heff` more ill-conditioned.
   - The validation script therefore uses `gradientStep = 0.005` and `maxIter = 50`.

4. `info.converged = false` is acceptable for Stage 3.
   - The stage acceptance criteria are successful script execution, unit-modulus phases, saved convergence curve, path gain not lower than random, and SNR not lower than random.
   - Formal convergence tuning is deferred until the figure-reproduction stage.

本文档只记录论文未明确给出、但代码复现必须补充的内容。凡是这里的内容都属于“合理复现假设”，不能写成论文原文。

## 当前已识别的合理复现假设

1. 信道几何距离未完整给出。
   - 合理复现假设：先采用可控的 Rician 随机信道模型，并加入路径损耗指数 `alpha = 2`。
   - 后续如果需要几何建模，再明确基站、RIS、目标坐标。

2. Rician 信道生成细节未完整给出。
   - 合理复现假设：使用 `K = 10 dB` 的 LoS 加 NLoS 复高斯模型。
   - LoS 阵列响应、阵元间距、角度分布需要后续人工确认或从相关文献补充。

3. 噪声功率设置不够明确。
   - 论文图3文字称发射功率和噪声功率基准都定为 10 dBm。
   - 合理复现假设：先把噪声功率作为显式参数 `noisePower_dBm`，并在图3中默认设置为 10 dBm；后续检查这是否符合 SNR 量级。

4. CD 算法细节未在论文正文中展开。
   - 合理复现假设：参考坐标下降相位优化基线，每次更新一个 RIS 单元相位，并以路径增益或 SNR 为目标。
   - 具体更新式需要单独推导或参考论文引用文献[38]。

5. ADMM 中 `T` 矩阵维度和增广变量维度需要核对。
   - 论文从 `N_r` 维相移向量扩展到 `N_r + 1` 维变量，但 PDF 公式排版存在压缩。
   - 合理复现假设：实现前先写小尺寸矩阵测试，验证目标函数等价性。

6. FMCW 调制方式需要确认。
   - 论文估计模型中讨论三角波上下扫频，实验图5和图6可能可用等效 chirp 序列距离-多普勒处理实现。
   - 合理复现假设：先实现标准 FMCW 数据立方体和 2D FFT，再决定是否补充上下扫频拍频显式估计。

7. 目标 RCS 细节未区分四个目标。
   - 论文表1给出 `RCS = 1`，图5文字提到强/弱目标。
   - 合理复现假设：第一版所有目标 RCS 相同；如需复现强弱差异，再记录每个目标 RCS 设置。

8. 随机性需要可复现。
   - 合理复现假设：默认固定 `rngSeed = 20251009`，与论文网络首发日期对应，便于复现实验结果。

## 后续待确认

- `H_rd` 的物理维度是否代表 RIS 到目标、目标到 RIS、还是目标散射后的等效矩阵。
- 接收信号中的双程 RIS 结构是否应写成 `H_sr^H * Phi * H_rd * Phi^H * H_sr`，还是需要转置/共轭修正。
- 图3和图4横轴具体取值范围。
- 图6 距离轴和多普勒轴的 FFT 点数、窗函数、归一化和动态范围。

## Stage 2 Assumptions Added

1. 本阶段采用 `Hsr: Nr x Nt`，`Hrd: Nr x Nr`。
   - 这是为了使 `Heff = Hsr^H * Phi * Hrd * Phi^H * Hsr` 得到 `Nt x Nt` 的等效信道。
   - `Hrd` 在代码中解释为 RIS 域目标散射/回波等效矩阵，而不是已完全物理展开的单程 RIS-target 信道。

2. 默认几何距离采用：
   - source-to-RIS distance: `15 m`
   - RIS-to-target effective distance: `20 m`
   - reference distance: `1 m`
   - path loss exponent: `2`
   这些距离并非论文表1给出，属于合理复现假设。

3. Rician 信道生成采用：
   - `K = 10 dB`
   - deterministic unit-norm ULA steering outer product as LoS component
   - circular complex Gaussian random matrix as NLoS component
   - path loss applied as amplitude scale `sqrt((d0/d)^alpha)`

4. `generate_channels.m` 默认在函数内根据 `params.repro.rngSeed` 重置随机种子。
   - 优点：基础验证可重复。
   - 后续做 Monte Carlo 仿真时，需要增加选项避免每次循环生成同一个信道。

5. 当前名义 SNR 绝对值不作为论文数值复现结论。
   - 第二阶段只验收维度、功率约束和单调性。
   - 当前 `noisePower_dBm = 10` 来自论文图3文字描述，但与双路径损耗结合后会得到很低的 SNR。后续如需匹配论文曲线，需要重新审查噪声功率定义、带宽噪声、接收增益和归一化方式。

6. 论文和人工建议都作为待验证输入。
   - 若公式、维度或趋势与实际 MATLAB 验证不一致，后续以可复现实验和维度自洽为准，并在本文档中记录偏差原因。
