# OCI Always Free Arm (A1.Flex) VM 创建器

[![Try to Create OCI VM](https://github.com/bluestreakxmu/oci-free-arm-instance/actions/workflows/create-vm.yml/badge.svg)](https://github.com/bluestreakxmu/oci-free-arm-instance/actions/workflows/create-vm.yml)

本仓库包含一个 GitHub Actions 工作流，用于在你的 Oracle Cloud Infrastructure (OCI) 账号中自动尝试创建一台 “Always Free” `VM.Standard.A1.Flex` (Arm) 计算实例。

之所以需要这样做，是因为 “Always Free” Arm 实例非常热门，经常因为需求过高而不可用，并返回 `"Out of host capacity."` 错误。你也可以尝试升级到 `pay as you go` 计划，这样成功获取可用实例的概率会高很多。请务必保持在免费额度内，并经常检查费用。

## 功能特性

* **完全自动化：** 全部运行在 GitHub Actions 中。你不需要在本地电脑上运行任何东西。
* **持续重试：** 工作流每 10 分钟运行一次，持续重试，直到成功创建 VM。
* **安全：** 所有敏感凭据、密钥和 ID 都存储在加密的 GitHub Secrets 中。仓库本身不包含私密信息，可以安全公开。
* **快速：** 使用 GitHub 缓存保存 `oci-cli` 安装内容，后续运行会更快。
* **信息清晰：** VM 创建成功时会向 Telegram 发送通知。如果你希望每次尝试都收到状态更新，也可以配置 Discord 通知。

---

## 使用方法

要使用本项目，你需要 **Fork** 此仓库，并将 OCI 凭据配置为 GitHub Secrets。

### 前置条件

* 一个 Oracle Cloud Infrastructure (OCI) “Always Free” 账号。
* 一个 GitHub 账号。
* 一个用于接收通知的 Telegram 账号，或 Discord 服务器/频道。

---

## 步骤 1：Fork 此仓库

点击页面右上角的 **"Fork"** 按钮。这会在你自己的 GitHub 账号下创建此仓库的副本。后续所有步骤都在 **你的 fork 仓库** 中完成。

## 步骤 2：生成 OCI API 凭据

这是最详细的一步。你需要从 OCI 账号和本地电脑中收集 **11 项信息**。

### A. 核心 ID：Tenancy、User、Region

1. 登录 OCI Console。
2. **Tenancy OCID：** 点击右上角的 **Profile icon** -> **Tenancy: [your_tenancy_name]**。
    * 复制 **OCID** 值。这就是你的 `OCI_CLI_TENANCY`。
    * *注意：对于 “Always Free” 账号，这通常也是你的 `COMPARTMENT_ID`。*
3. **User OCID：** 点击 **Profile icon** -> **User Settings**。
    * 复制 **OCID** 值。这就是你的 `OCI_CLI_USER`。
4. **Region Identifier：** 查看控制台右上角的区域，例如 “Singapore”。
    * 将鼠标悬停在区域上，或点击它以查看区域标识符，例如 `ap-singapore-1`。这就是你的 `OCI_CLI_REGION`。

### B. OCI API Key：私钥和 Fingerprint

1. 在同一个 **User Settings** 页面中，点击左侧菜单里的 **"API Keys"**。
2. 点击 **"Add API Key"** 按钮。
3. 选择 **"Generate API Key Pair"**。
4. 点击 **"Download Private Key"** 并保存 `oci_api_key.pem` 文件。**不要丢失这个文件。**
5. 点击 **"Add"** 按钮。
6. 随后会弹出 “Configuration File Preview”。从其中复制 `fingerprint` 值。这就是你的 `OCI_CLI_FINGERPRINT`。

### C. VM 相关 ID：Subnet、Image、AD

1. **Subnet ID：**
    * 进入 OCI Console 菜单 -> **Networking** -> **Virtual Cloud Networks**。
    * 点击你的 VCN，通常会有一个默认 VCN。
    * 点击左侧菜单中的 **"Subnets"**。
    * 点击你的 public subnet，例如 `Public Subnet ...`。
    * 复制该 subnet 的 **OCID**。这就是你的 `SUBNET_ID`。
2. **Availability Domain (AD) Name：**
    * 进入 OCI Console 菜单 -> **Compute** -> **Instances**。
    * 点击 **"Create Instance"**。
    * 在 **"Placement"** 部分，查看 **"Availability Domain"** 下拉框。你通常只有一个可选项。
    * 完整复制它显示的名称，例如 `KClJ:AP-SINGAPORE-1-AD-1`。这就是你的 `AD_NAME`。
3. **Image ID：**
    * 在同一个 “Create Instance” 页面中，在 **"Image and shape"** 部分点击 **"Change Image"**。
    * 选择 **"Canonical Ubuntu"**，或选择你想用的其他系统镜像。
    * 点击镜像名称，例如 “Canonical Ubuntu 22.04”。右侧会滑出详情面板。
    * 复制镜像的 **OCID**。这就是你的 `IMAGE_ID`。
    * 现在可以取消 “Create Instance” 创建向导。
    * 如果仍然找不到镜像，可以查看此网站，按区域选择镜像并复制对应 OCID：<https://docs.oracle.com/en-us/iaas/images/>
    * 将这个 `IMAGE_ID` 配置到你的 action 环境中。
4. **OCPU 和内存**
    * 此 action 默认创建 4 个 OCPU、24 GB 内存的实例。
    * 你可以在 action 中修改这一行：`--shape-config '{"ocpus":4,"memoryInGBs":24}' \`
6. **启动卷和实例名称**
    * 此 action 默认创建 `200` GB 启动卷，实例名称为 `coolify-vm`。
    * 你可以在 action 中修改启动卷大小：`--boot-volume-size-in-gbs 200' \`
    * 你也可以在同一个命令中修改实例名称：`--display-name "coolify-vm"`

### D. 你的 SSH 公钥

这是你之后登录新服务器时使用的密钥。

1. 打开本地终端。
2. 检查是否已有密钥：`cat ~/.ssh/id_rsa.pub`
3. **如果显示了密钥：** 复制完整输出，内容通常以 `ssh-rsa...` 开头。这就是你的 `SSH_PUBLIC_KEY`。
4. **如果显示 “No such file”：** 运行 `ssh-keygen -t rsa -b 2048`。连续按三次 Enter 接受默认设置。然后再次运行 `cat ~/.ssh/id_rsa.pub` 并复制该公钥。

---

## 步骤 3：配置通知

如果你没有 Discord，推荐使用 Telegram。

### 方案 A：Telegram Bot

1. 打开 Telegram，搜索 **@BotFather**。
2. 发送 `/newbot`，按提示创建机器人，然后复制 bot token。这就是你的 `TELEGRAM_BOT_TOKEN`。
3. 给你新建的 bot 发送任意一条消息。
4. 在浏览器中打开下面的 URL，将 `<BOT_TOKEN>` 替换成你的 token：

```text
https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
```

5. 在返回内容中找到 `chat.id`，这就是你的 `TELEGRAM_CHAT_ID`。

### 方案 B：Discord Webhook

1. 打开你的 Discord 服务器。右键点击一个频道名称，然后点击 **"Edit Channel"**。
2. 进入 **"Integrations"** 标签页。
3. 点击 **"Webhooks"** -> **"New Webhook"**。
4. 给它起一个名字，例如 “OCI Notifier”，然后点击 **"Copy Webhook URL"**。

---

## 步骤 4：配置 GitHub Secrets

进入你的 fork 仓库页面。

1. 点击 **"Settings"** 标签页。
2. 在左侧菜单中，点击 **"Secrets and variables"** -> **"Actions"**。
3. 对下面列出的 secrets，逐个点击 **"New repository secret"** 创建。

#### **VM Secrets**

* `OCI_COMPARTMENT_ID`：步骤 2A 中的 Tenancy OCID
* `IMAGE_ID`：步骤 2C 中的 Image OCID
* `OCI_SUBNET_ID`：步骤 2C 中的 Subnet OCID
* `AD_NAME`：步骤 2C 中的 Availability Domain 名称
* `SSH_PUBLIC_KEY`：步骤 2D 中以 `ssh-rsa...` 开头的公钥

#### **Authentication Secrets**

* `OCI_CLI_REGION`：步骤 2A 中的区域，例如 `ap-singapore-1`
* `OCI_CLI_USER`：步骤 2A 中的 User OCID
* `OCI_CLI_TENANCY`：步骤 2A 中的 Tenancy OCID
* `OCI_CLI_FINGERPRINT`：步骤 2B 中的 fingerprint
* `OCI_CLI_KEY_CONTENT`：用文本编辑器打开步骤 2B 下载的 `oci_api_key.pem` 文件。复制从 `-----BEGIN PRIVATE KEY-----` 到 `-----END PRIVATE KEY-----` 的完整内容，并粘贴到这里。

#### **Notification Secrets**

使用 Telegram：

* `TELEGRAM_BOT_TOKEN`：步骤 3 中得到的 bot token
* `TELEGRAM_CHAT_ID`：步骤 3 中得到的 chat ID

或者使用 Discord：

* `DISCORD_WEBHOOK_URL`：步骤 3 中复制的 Discord Webhook URL

### 自动化配置 secrets

在 Windows 上，你可以通过本地 JSON 文件一次性设置所有 GitHub Actions secrets，不需要在 GitHub UI 中逐个填写。

1. 将 `scripts/secrets.example.json` 复制为 `scripts/secrets.local.json`。
2. 按照上面的步骤，把对应值填入 `scripts/secrets.local.json`。
   * 可以使用 `OCI_CLI_KEY_FILE` 指向你下载的 `oci_api_key.pem`，也可以使用 `OCI_CLI_KEY_CONTENT` 直接填写私钥内容。
   * `scripts/secrets.local.json` 和 `*.pem` 文件已被 Git 忽略，不应提交。
3. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-github-actions.ps1 -TriggerWorkflow
```

该脚本会在需要时通过 `winget` 安装 GitHub CLI；如果你尚未登录 GitHub，它会提示你登录；然后设置仓库 secrets，并可选启动 workflow。如果你使用 Telegram，可以把 `DISCORD_WEBHOOK_URL` 留空。

---

## 步骤 5：运行工作流

全部准备完成。现在只需要启动流程。

1. 进入你的 fork 仓库的 **"Actions"** 标签页。
2. 在左侧边栏中点击 **"Try to Create OCI VM"**。
3. 你会看到一条提示：“This workflow has a `workflow_dispatch` event.” 点击右侧的 **"Run workflow"** 按钮，然后再次点击 **"Run workflow"**。

这会启动第一次运行。从此之后，`schedule` 会每 10 分钟自动运行一次。你可以在 "Actions" 标签页查看每次运行的日志。如果使用 Telegram，只有 VM 创建成功时才会收到通知。

---

## 重要：成功后应该做什么

某一天，你会在 Telegram 或 Discord 中收到一条 **success** 通知。这表示你的 VM 已经创建成功。

一看到成功通知，你就 **必须** 禁用此 workflow。

1. 进入仓库的 **"Actions"** 标签页。
2. 点击左侧边栏里的 **"Try to Create OCI VM"**。
3. 点击右侧的 **three-dot (...)** 菜单。
4. 点击 **"Disable workflow"**。

如果不这样做，action 会继续每 10 分钟运行一次，并尝试创建 *另一台* VM，最终只会让日志里充满错误。

你的 VM 会在 OCI Console 中进入 provisioning 状态。现在可以使用你提供的 SSH 密钥登录服务器。

## 许可证

本仓库基于 [MIT License](LICENSE) 发布。
