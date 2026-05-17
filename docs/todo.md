# TODO

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
