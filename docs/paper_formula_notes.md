# Paper Formula Notes

## Stage 3 ADMM Phase Optimization Notes

Current executable dimensions:

```text
Hsr: Nr x Nt
Hrd: Nr x Nr
v:   Nr x 1, |v_i| = 1
Phi = diag(v): Nr x Nr
Heff = Hsr^H * Phi * Hrd * Phi^H * Hsr: Nt x Nt
B: Nt x Nt
```

Stage 3 path-gain objective:

```text
gain(v) = ||Heff(v)||_F^2
Heff(v) = Hsr^H * diag(v) * Hrd * diag(v)^H * Hsr
```

This is the executable path-gain objective for the current code convention. It is not claimed to be identical to the paper's printed quadratic `T`-matrix objective, because the current `Hrd: Nr x Nr` convention makes `||Heff||_F^2` quartic in `v`.

Implemented ADMM surrogate:

```text
x  : surrogate phase-update variable
u  : unit-modulus projection variable
mu : consensus multiplier
rho: consensus penalty
```

Iteration outline:

```text
1. initialize u = v0, x = u, mu = 0
2. estimate finite-difference gradient of gain(exp(j theta)) with respect to theta
3. take a conservative backtracking phase step for the x update
4. project u = exp(j angle(x - mu/rho))
5. update mu = mu + rho * (u - x)
6. record objective, primal residual, and dual residual
```

Stage 3 validation used:

```text
maxIter = 50
rho = 1
gradientStep = 0.005
finiteDifferenceStep = 1e-4
```

Important: larger steps increased path gain but worsened `pinv(Heff)` conditioning and reduced ZF-normalized SNR. The conservative step is a stability choice based on actual validation, not a figure-matching adjustment.

## 论文核心问题

论文研究 RIS 辅助 MIMO-FMCW 雷达在非视距场景下的目标距离和速度估计。RIS 用于重构传播链路，使基站发射信号经 RIS 反射后照射遮挡目标，再由回波链路返回并形成可处理的雷达回波。

## 场景模型

- 基站发射天线数：`N_t`。
- 基站接收天线数：`N_b`。
- RIS 反射单元数：`N_r`。
- RIS 部署在基站与目标之间，用于建立非视距辅助传播链路。
- 论文默认存在 MIMO 与 RIS 之间的控制链路。

## 发射信号

FMCW 发射信号形式：

```text
s(t) = A0 * exp(j * (2*pi*fc*t + pi*gamma*t^2 + phi0))
```

其中 `fc` 为起始频率，`T` 为调频周期，`gamma` 为调频斜率，`A0` 为初始幅度，`phi0` 为初始相位。

## 接收信号

论文给出的接收信号模型为：

```text
y = H_sr^H * Phi * H_rd * Phi^H * H_sr * B * s + n
```

需要后续重点检查的地方：

- 论文符号中 `H_rd` 被描述为 RIS 到目标的信道矩阵，但接收模型中涉及双程链路，维度和物理含义需要在代码实现前再次核对。
- `H_sr`、`H_rd`、`Phi`、`B` 的矩阵维度必须通过小尺寸数值测试验证。

## 差拍信号

论文给出混频、滤波后的中频差拍信号：

```text
r_b(t) = channel_gain * B * s * A0^2
         * exp(j * [2*pi*(fc*tau - B/(2T)*tau^2 + B/T*tau*t) + phi0 + phi1])
         + n
```

其中 `tau` 为传播时延，`phi1` 为目标反射引起的相位差。上式在 PDF 中存在排版和符号压缩，后续实现需要重新整理成代码可执行形式。

## 距离和速度估计

静止目标拍频：

```text
f_IF = gamma * tau = 4 * B * R0 / (T * c)
R0 = f_IF * T * c / (4 * B)
```

运动目标上下扫频拍频：

```text
f_up   = gamma * tau - f_d = 4 * B * R0 / (T * c) - 2*v/lambda0
f_down = gamma * tau + f_d = 4 * B * R0 / (T * c) + 2*v/lambda0
```

距离和速度：

```text
R0 = (f_up + f_down) * T * c / (8 * B)
v  = (f_up - f_down) * lambda0 / 4
```

分辨率：

```text
Delta_R = c / (2 * B)
Delta_v = lambda0 / T
```

注意：论文图2描述三角调频，但实验参数表中给出单个 chirp 周期和 chirp 数量。后续需要明确图5、图6代码到底采用三角扫频、锯齿扫频还是等效距离-多普勒处理。

## 优化问题

论文将目标反射后的 SNR 最大化写为：

```text
max_{B, v} || H_sr^H * Phi * H_rd * Phi^H * H_sr * B ||_F^2 / sigma^2
s.t. ||B||_F^2 <= P
     Phi = beta * diag(v), |v(i)| = 1
```

该问题关于 `B` 和 `Phi` 非凸。论文采用交替优化思想：

- 固定 `Phi`，用 ZF 设计 `B`。
- 固定或等效处理 `B`，用路径增益最大化准则通过 ADMM 优化 `Phi`。

## ZF 预编码

论文目标：

```text
H_eff * B = I
B = Pi^dagger = Pi^H * (Pi * Pi^H)^(-1)
```

其中 `Pi` 表示等效信道。实现时需要处理不可逆、病态矩阵和功率归一化。

## RIS ADMM 相移优化

论文将路径增益最大化问题转成：

```text
min 0.5 * x^H * T * x
s.t. |u(i)| = 1, u = x
```

增广拉格朗日变量包括 `x`、`u`、`mu` 和惩罚参数 `rho`。主要迭代：

```text
u_{k+1} = phase(x_k - rho^(-1) * mu_k)
x_{k+1} = (rho * I + T)^(-1) * (rho * u_{k+1} + mu_k)
mu_{k+1} = mu_k + rho * (u_{k+1} - x_{k+1})
```

论文算法表中还给出 `mu_{k+1} = T * x_{k+1}` 的等价更新关系，需要后续确认采用哪一种更稳定。

## 仿真参数初版

来自论文表1和实验段落：

| 参数 | 符号 | 数值 |
| --- | --- | --- |
| 发射天线数 | `N_t` | 4 |
| 接收天线数 | `N_b` | 4 |
| 载波频率 | `f_c` | 77 GHz |
| 扫频带宽 | `B` | 500 MHz |
| 发射功率 | `P` | 10 dBm |
| 单个 chirp 时间 | `T` | 50 us |
| 采样率 | `f_s` | 2 MHz |
| chirp 数量 | `N_chirp` | 256 |
| 光速 | `c` | 3e8 m/s |
| RCS | `RCS` | 1 |
| 最大迭代次数 | `k_max` | 1000 |
| Rician 因子 | `K` | 10 dB |
| 路径损耗指数 | `alpha` | 2 |
| 收敛阈值 | `epsilon` | 1e-2 / 1e-3 / 1e-4 |

多目标设置：

| 目标 | 距离 | 速度 |
| --- | --- | --- |
| Target 1 | 25 m | -1 m/s |
| Target 2 | 20 m | 1 m/s |
| Target 3 | 10 m | -1 m/s |
| Target 4 | 5 m | 1 m/s |

## 图表目标

- 图3：ADMM 与 CD 的 SNR 随 `N_r` 增大而提高，ADMM 始终高于 CD。
- 图4：SNR 随发射功率增大而提高，ADMM 高于 CD；论文文字强调 `N_r = 16` 的 ADMM 可优于 `N_r = 64` 的 CD。
- 图5：四目标距离-时间三维幅度谱，展示多目标距离轨迹和幅度分布。
- 图6：`N_r = 4, 16, 64` 下 ADMM/CD 距离-多普勒图；RIS 单元数增加后目标峰值更清晰，背景噪声相对降低。

## Stage 2 Actual Matrix Convention

第二阶段基础模型采用以下可执行维度约定：

```text
Nt = 4
Nb = 4
Nr = 16 by default
Hsr: Nr x Nt
Hrd: Nr x Nr
Phi: Nr x Nr
Heff = Hsr^H * Phi * Hrd * Phi^H * Hsr
Heff: Nt x Nt
B: Nt x Nt
```

这里的 `Hrd` 暂时不是严格的 RIS-to-target 单程信道，而是 RIS 域的目标散射/回波等效矩阵。采用该约定的原因是它能与论文接收模型中的双 RIS 相移结构形成维度一致的 `Heff`。该处理已经同步记录到 `reproduction_assumptions.md`。

## Stage 2 SNR Formula

代码中 `compute_snr.m` 使用：

```text
SNR_linear = ||Heff * B||_F^2 / noisePower_W
SNR_dB = 10 * log10(SNR_linear)
```

其中 `noisePower_W` 必须是线性瓦特值，不能传入 dBm。

## Stage 2 ZF Formula

代码中 `design_precoder_zf.m` 使用：

```text
B_raw = pinv(Heff)
P_raw = ||B_raw||_F^2
B = sqrt(P_tx_W / P_raw) * B_raw
```

归一化后：

```text
||B||_F^2 = P_tx_W
```

ZF 误差记录为：

```text
rawRelativeError = ||Heff * B_raw - I||_F / ||I||_F
relativeError = ||Heff * B - scale * I||_F / ||scale * I||_F
```

注意：归一化后的 `Heff * B` 等于缩放后的单位阵，而不是单位阵本身。这是功率约束下 ZF 预编码的预期结果。
