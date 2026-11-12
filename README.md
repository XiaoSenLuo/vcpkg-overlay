# vcpkg-overlay

本仓库用于扩展 [vcpkg](https://github.com/microsoft/vcpkg)：提供用户自定义的
ports、toolchains 与 triplets，并附带三个功能完全一致的部署脚本
（bash / batch / PowerShell），可将这些内容一键部署进任意 vcpkg 安装根目录，
并能通过 `--restore` 完整还原。

## 目录结构

```
ports/                          自定义端口（overlay ports）
├── ck                          C99 并发原语 / 无锁数据结构
├── corrosion                   Rust 与 CMake 的集成模块
├── cppcommon                   C++ 通用工具库
├── cppserver                   基于 Asio/OpenSSL 的异步 C++ 网络库
├── poco                        POCO C++ 基础库（补丁端口）
├── slint                       Slint C++ GUI 运行时
├── vcpkg-cargo                 cargo 构建辅助端口（vcpkg_cargo_* 函数）
├── vcpkg-tool-rust             Rust 工具链端口（rustc/cargo/std -> tools/rust）
├── zenoh-c                     Zenoh C API
└── zenoh-cpp                   Zenoh C++ API（header-only）
toolchains/
└── amd-linux.cmake             AMD 目标 Linux 交叉编译工具链（arm/x86/x64/arm64/riscv64，
                                支持 Yocto OECORE_NATIVE_SYSROOT）
triplets/community/
├── arm-amd-linux.cmake         ARM Linux triplet（静态库）
└── arm-amd-linux-dynamic.cmake ARM Linux triplet（动态库）
scripts/
└── generateRustSha.py          生成 Rust 官方分发档 SHA512 的维护工具
test/                           测试（见下文"测试"）
deploy-overlay.sh               部署脚本（Linux / macOS，bash）
deploy-overlay.bat              部署脚本（Windows，cmd）
deploy-overlay.ps1              部署脚本（Windows，PowerShell）
```

## 部署与还原

三个脚本实现同一功能，任选其一即可。

### 用法

```sh
# Linux / macOS
./deploy-overlay.sh --vcpkg-root <path> [--restore]
```

```bat
:: Windows (cmd)
deploy-overlay.bat --vcpkg-root <path> [--restore]
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File deploy-overlay.ps1 --vcpkg-root <path> [--restore]
```

### 参数

| 参数 | 说明 |
| --- | --- |
| `--vcpkg-root <path>` | vcpkg 安装根目录（必填）。未指定时报错退出并提示先安装 vcpkg；目录必须包含 `scripts/toolchains`，否则视为无效的 vcpkg 根 |
| `--restore` | 还原模式：删除部署时拷贝的全部文件，将 `*.origin` 重命名回原文件名，并清理因此变空的目录 |
| `-h` / `--help` | 显示帮助 |

### 部署内容

| 仓库目录 | 部署到 |
| --- | --- |
| `ports/` | `<vcpkg-root>/overlay/ports` |
| `toolchains/` | `<vcpkg-root>/scripts/toolchains` |
| `triplets/` | `<vcpkg-root>/triplets` |

目录递归合并，不会删除目标中已有的其他内容（例如 `triplets/community/`
下原有的社区 triplet 保持不动）。

### 重名冲突处理

- 拷贝时遇到重名文件，先将原文件重命名为 `<file-name>.origin`，再写入新文件；
- `--restore` 时删除拷贝的文件，并将 `<file-name>.origin` 恢复为 `<file-name>`；
- 安全护栏：若检测到上次部署留下的 `*.origin` 尚未恢复（说明未执行
  `--restore` 就再次部署，会把第二次部署的副本误认为原件），脚本拒绝部署并
  提示先执行 `--restore`。

### 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `1` | 未指定 `--vcpkg-root`、无效 vcpkg 根、检测到未恢复的上次部署、拷贝/删除失败 |
| `2` | 参数错误（未知选项、`--vcpkg-root` 缺少取值） |

## 部署后使用 vcpkg

```sh
# 使用 overlay 端口安装（经典模式）
vcpkg install zenoh-cpp --overlay-ports=<vcpkg-root>/overlay/ports

# 使用自定义 triplet（部署后位于 <vcpkg-root>/triplets/community，vcpkg 自动可见）
# triplet 需要通过 VCPKG_ROOT 环境变量定位工具链，并自动 chainload
# <VCPKG_ROOT>/scripts/toolchains/amd-linux.cmake
export VCPKG_ROOT=/path/to/vcpkg
vcpkg install ck:arm-amd-linux --overlay-ports=$VCPKG_ROOT/overlay/ports
```

manifest 模式下可在 `vcpkg-configuration.json` 中配置 `"overlay-ports"` 指向
`<vcpkg-root>/overlay/ports`，效果相同。

## 测试

```sh
# 部署脚本交叉验证矩阵：{sh, bat, ps1} 部署 × {sh, bat, ps1} 恢复，共 9 组合，
# 每组校验部署内容、.origin 原件内容以及恢复后与初始状态逐字节一致
./test/cross-test.sh <vcpkg-root>

# zenoh-cpp 端到端测试（安装 -> 编译 -> 运行发布/订阅回路）
./test/run-test.sh                       # Linux / macOS
powershell -ExecutionPolicy Bypass -File test/run-test.ps1   # Windows
```

其余测试工程（`test/zenoh-demo`、`test/slint-demo`、`test/cargo-smoke`）
由上述脚本或各自目录内的说明驱动。

## SHA512 维护工具

`vcpkg-tool-rust` 端口引用的 Rust 官方分发档哈希表由
`scripts/generateRustSha.py` 维护：

```sh
python scripts/generateRustSha.py --version 1.98.1 --std        # rust-std 分发档
python scripts/generateRustSha.py --version 1.98.1 --toolchain  # 各宿主工具链分发档
```

## 许可证

[MIT](LICENSE)
