#!/bin/bash
# Log file for debugging
source shell/custom-packages.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "编译固件大小为: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 同步第三方软件仓库run/ipk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
#  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo
  git clone --depth=1 https://github.com/turbo-feng/imm-store.git /tmp/store-run-repo  

  # 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/x86/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
fi

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."
########################################################  自定义位置   #########################################################
# ============= imm仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
#PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
## PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
# 文件管理器  可视化编辑器和下载删除
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
# 静态文件服务器dufs(推荐) 配合samba实现远程轻nas管理
#PACKAGES="$PACKAGES luci-i18n-dufs-zh-cn"

# ram释放
PACKAGES="$PACKAGES luci-app-ramfree"
PACKAGES="$PACKAGES luci-i18n-ramfree-zh-cn"
#CF隧道
PACKAGES="$PACKAGES luci-app-cloudflared"
PACKAGES="$PACKAGES luci-i18n-cloudflared-zh-cn"
# 自动端口映射，在外网访问服务&&内网设备访问外网
#PACKAGES="$PACKAGES luci-app-upnp"
#PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-i18n-natmap-zh-cn"
# 动态域名DDNS+皎月连
PACKAGES="$PACKAGES luci-i18n-ddns-go-zh-cn"
PACKAGES="$PACKAGES luci-app-ddns-go"
PACKAGES="$PACKAGES luci-app-natpierce"
# 跨平台链接下载
#PACKAGES="$PACKAGES luci-i18n-aria2-zh-cn"
#PACKAGES="$PACKAGES luci-app-aria2"
# 在线升级
PACKAGES="$PACKAGES luci-i18n-attendedsysupgrade-zh-cn"
PACKAGES="$PACKAGES luci-app-attendedsysupgrade"
# DNS选择，提高网页速度
PACKAGES="$PACKAGES luci-i18n-smartdns-zh-cn"
# 系统信息统计
PACKAGES="$PACKAGES luci-i18n-statistics-zh-cn"
PACKAGES="$PACKAGES luci-app-statistics"
# 拦截IP
PACKAGES="$PACKAGES luci-i18n-banip-zh-cn"
PACKAGES="$PACKAGES luci-app-banip"
#网易云音乐解锁
PACKAGES="$PACKAGES luci-app-unblockneteasemusic"
# KMS服务器激活
PACKAGES="$PACKAGES luci-app-vlmcsd"
PACKAGES="$PACKAGES luci-i18n-vlmcsd-zh-cn"
#############核心包
PACKAGES="$PACKAGES kmod-mlx5-core"

# ======== shell/custom-packages.sh =======
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"


# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
