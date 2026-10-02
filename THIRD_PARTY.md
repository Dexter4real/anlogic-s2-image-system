# 依赖与来源

基础来源：2026 安路赛题二配套 lab_ex3_osd_SC500_720P（Lab3），官方 MIPI/ISP/DDR/HDMI 通路。

公开仓库未包含厂商原包、加密 IP、TD 工具/许可证、字体、安路 Logo ROM、位流或个人电脑日志。官方基础代码包含 Anlogic、MiLianKe 的版权及学习用途说明，不能将公开展示许可等同于对全部依赖的再授权。

完整工程需向比赛官方资源渠道取得 Lab3 及其适用工具许可。s2_osd 依赖原文件 anlogic_logo_rom.v 与 osd_char_lib.v；完整采集显示还依赖 Lab3 的 video_out、DDR、PLL、MIPI/HDMI IP、顶层与约束。本公开仓库的默认测试只运行不依赖这些模块的控制器和像素算法。

Pillow、Icarus Verilog 是外部测试工具，按各自许可证使用。本仓库没有重新分发这些软件。
