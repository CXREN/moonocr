# moonocr

纯 MoonBit 实现的光学字符识别（OCR）引擎。它读取一张图像，找到其中的文本，返回识别出的字符——不依赖 MoonBit 核心库以外的任何第三方包。

引擎识别 **数字 `0`-`9`、字母 `A`-`Z` / `a`-`z`（共 62 类）**，支持单行与多行，对噪声和不均匀光照有一定鲁棒性。

## 项目目标

- 用纯 MoonBit 从零实现一条完整的 OCR 管线，补上 MoonBit 生态中「图像 → 文本」的底座；
- 零外部依赖，可被 `moon add` 直接组合，也可编译到 wasm 部署；
- 以可测试、可验证的鲁棒性语义（缩放不变、噪声剔除、部件装配）为目标，而非单纯追求识别类别数量。

## 管线

```
图像 ──▶ 解码 ──▶ 二值化 ──▶ 分割 ──▶ 特征 ──▶ 分类 ──▶ 文本
(BMP/PGM/PPM)  (Otsu/固定/自适应)  (连通域+行分组+部件)  (8×8 网格)  (最近邻)
```

| 阶段 | 模块 | 说明 |
|------|------|------|
| 图像模型 | `image.mbt` | `Image`、BT.601 `rgb_to_gray` |
| 解码 | `bmp.mbt` / `pgm.mbt` / `ppm.mbt` | `parse_bmp`、`parse_pgm`(P1/P2/P4/P5)、`parse_ppm`(P3/P6) |
| 二值化 | `binarize.mbt` | 固定阈值 / Otsu / 自适应 / Sauvola / Niblack |
| 矫正 | `deskew.mbt` | 投影直方图、图像旋转、倾斜检测与 deskew |
| 分割 | `segment.mbt` | 连通域、噪声过滤、行分组、部件装配 |
| 特征 | `feature.mbt` | 保持纵横比的 8×8 网格 |
| 分类 | `classify.mbt` | 汉明距离最近邻 / 加权 / 平移增强 |
| 识别 | `recognize.mbt` | 单行 / 多行 |

## 编译与运行

需要 [MoonBit](https://www.moonbitlang.com/) 工具链（`moon`）。

```sh
moon check     # 类型检查
moon test      # 运行全部测试（79 项）
moon bench     # 运行基准
```

命令行演示（每个参数是一行文本，渲染成图像后再识别回来）：

```sh
moon run cmd/main -- Hello World 42
```

## 示例

上面的命令会输出：

```
input:
  Hello
  World
  42
output: Hello
World
42
```

引擎内部先把文本渲染成 8×8 位图字形（`#` 为墨迹、`.` 为纸白），再走完整管线识别。例如字母 `A` 与数字 `7` 的字形：

```
字母 A             数字 7
...##...          .######.
..####..          .....##.
.##..##.          ....##..
.##..##.          ...##...
.######.          ...##...
.##..##.          ...##...
.##..##.          ...##...
.##..##.          ...##...
```

## 使用教程

### 解码图像

```moonbit
let img = parse_pgm(bytes) // 或 parse_bmp / parse_ppm
let gray = img.at(x, y)    // 0..=255，0 为墨迹，255 为纸白
```

所有解码器返回灰度 `Image`，输入非法时抛出 `DecodeError`。

### 识别文本

```moonbit
let text = recognize_text(img)   // 多行，以 "\n" 连接
let line = recognize_digits(img) // 单行
```

两者内部用 Otsu 二值化、滤除噪声斑点、分割字形（并把 `i`/`j` 的点和竖重新装配），再与 62 个内置模板做最近邻分类。

### 底层构建块

```moonbit
let bin = binarize_otsu(img)
let adaptive = binarize_adaptive(img, window=15, c=20)

let components = connected_components(bin)
let big = filter_small(components, min_area=8)
let lines = group_lines(big)
let glyphs = merge_parts(lines[0])

let grid = glyph_grid(bin, glyphs[0], size=8)
let m = classify(grid, alphanumeric_references()) // Match?
```

## 支持的图像格式

- **BMP** — 8/24/32 位无压缩 `BI_RGB`，自底向上。
- **PGM** — P1（ASCII 位图）、P2（ASCII 灰度）、P4（位图）、P5（二进制灰度），`maxval ≤ 255`。
- **PPM** — P3（ASCII RGB）、P6（二进制 RGB），`maxval ≤ 255`；用 BT.601 亮度转灰度。

另提供 `write_pgm_p5` / `write_ppm_p6` 编码器用于往返测试。

## 工作原理

- **二值化**：Otsu 求全局阈值；自适应版用积分图求局部窗口均值；Sauvola/Niblack 用局部均值与标准差应对光照不均。
- **矫正**：`deskew` 对轻微旋转的文本求水平投影直方图，在候选角度里选方差最大者旋转回正。
- **分割**：8 连通泛洪给墨迹区域打标签；按垂直重叠合并成行；`merge_parts` 把被细缝拆开的字形（如 `i`/`j` 的点）重新拼回；`filter_small` 滤除噪声。
- **特征**：每个字形的包围盒按保持纵横比的方式下采样到 8×8 网格，每格记录是否有半数以上像素为墨。
- **分类**：网格间汉明距离最近邻，可选加权距离与平移增强（shift 变体），对轻微偏心字形更鲁棒。参考模板走同一条特征管线生成，因此干净渲染必然与自身距离为 0。

## 测试

```sh
moon test   # 79 项测试，全部通过
```

## 限制

- 分类器基于内置 8×8 字体模板，未做训练；真实字体与重度变形会降低准确率。
- 仅识别 `0`-`9`、`A`-`Z`、`a`-`z`（不含标点与重音符号）。
- 核心库不做文件 I/O：解码器接收 `Bytes`，由调用方提供图像字节。

## 开源协议

Apache-2.0
