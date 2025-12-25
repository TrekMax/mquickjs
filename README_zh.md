MicroQuickJS（MQuickJS）中文版说明
============================

> 说明：本文件是面向使用与构建的中文概览（不逐段直译）。更完整的语义/规范细节请参考英文版 [README.md](README.md)。

## 简介

MicroQuickJS（简称 MQuickJS）是面向嵌入式系统的 JavaScript 引擎。

- 目标：在极小 RAM/ROM 占用下编译并运行 JavaScript。
- 语言：只支持接近 ES5 的一个子集，并默认启用更严格（stricter）的运行/语法约束。
- 与 QuickJS 的关系：复用部分代码，但内部实现为低内存设计（例如追踪式 GC、UTF-8 字符串等）。

## 构建（Makefile）

默认构建 `mqjs`（REPL/解释器）和 `example`（C API 示例）：

- 构建：`make`
- 清理：`make clean`
- 运行 JS 回归测试：`make test`

常用目标：
- 运行 microbench：`make microbench`

## 构建（CMake）

本仓库提供了 CMake 构建（与 Makefile 目标对齐），并且将生成的头文件输出到构建目录（不改动源码目录）。

- 配置+构建（Release）：
  - `cmake -S . -B build -DCMAKE_BUILD_TYPE=Release`
  - `cmake --build build -j`

- 运行测试（CTest）：
  - `ctest --test-dir build --output-on-failure`

### CMake 可选开关

- `-DMQJS_SMALL=ON/OFF`：对应 Makefile 的 `CONFIG_SMALL`（ON 时使用 `-Os`）
- `-DMQJS_WERROR=ON`：将警告视为错误
- `-DMQJS_ASAN=ON`：启用 AddressSanitizer
- `-DMQJS_SOFTFLOAT=ON`：启用软浮点相关宏与编译参数
- `-DMQJS_X86_32=ON` / `-DMQJS_ARM32=ON`：生成/构建 32 位相关输出（包含 bytecode 的 `-m32` 场景）
- `-DMQJS_BUILD_EXAMPLES=ON/OFF`：是否构建 `example`
- `-DMQJS_BUILD_TESTS=ON`：是否构建 `dtoa_test`、`libm_test`（C 测试可执行文件）

### 交叉编译时的“头文件生成”

`mqjs` 在编译前需要通过宿主工具生成若干头文件（例如 `mquickjs_atom.h` 等）。

交叉编译（target 编译器产物不可在宿主机运行）时，推荐做法：

1) 先在宿主机 native 构建出两个生成工具：
- `mqjs_stdlib_host`
- `example_stdlib_host`

2) 在交叉编译的 CMake 配置中直接指定这两个工具的路径：
- `-DMQJS_STDLIB_TOOL=/abs/path/to/mqjs_stdlib_host`
- `-DMQJS_EXAMPLE_STDLIB_TOOL=/abs/path/to/example_stdlib_host`

如不指定，交叉编译情况下会尝试用 `MQJS_HOST_CC`（默认 `gcc`）构建可在宿主机运行的生成工具。

## mqjs（REPL/解释器）

`mqjs` 可执行脚本，也可输出字节码（便于写入文件或固件 ROM）：

- 直接执行：`./mqjs path/to/script.js`
- 限制内存（示例）：`./mqjs --memory-limit 10k tests/mandelbrot.js`
- 输出字节码：`./mqjs -o out.bin tests/mandelbrot.js`
- 运行字节码：`./mqjs out.bin`

字节码与 CPU 的端序与字长（32/64 位）相关；在 64 位宿主机上可用 `-m32` 生成 32 位字节码，便于在 32 位嵌入式系统运行。

## stricter 模式（更严格子集）

MQuickJS 默认在更严格的子集模式下运行（大体上仍保持在其它 JS 引擎中可工作的写法）：

- 只允许严格模式构造：禁止 `with`；全局变量必须用 `var` 声明。
- 数组不允许“空洞”（hole）：例如跳跃式赋值会触发错误。
- 不支持直接 `eval` 访问/修改局部变量（只支持全局/间接 eval）。
- 不支持装箱（boxing）：例如 `new Number(1)`。

更完整的子集与行为差异列表请看 [README.md](README.md) 的 “JavaScript Subset Reference”。

## C API（简要）

- 引擎创建时需要提供一块内存 buffer；引擎只在这块 buffer 内分配。
- API 形态与 QuickJS 接近，但因为 GC 是可移动/可整理（compacting）的，C 侧需要避免长期持有可移动对象地址；按 [README.md](README.md) 的 C API 章节说明使用。

## 许可证

见 [LICENSE](LICENSE)。
