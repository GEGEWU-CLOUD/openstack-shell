#!/bin/bash
#部署openstack yoga版本 部署节点使用
#只适用于ubuntu20.04
set -e
source_pip="https://pypi.tuna.tsinghua.edu.cn/simple"
echo -e  "\033[36m
部署前须知：此脚本将半自动部署all-in-one版 
分布式对接ceph请注释main函数部分内容分节点执行此${0}脚本.
main函数部分：
software_source       # 所有节点执行 
kolla_kvm             # 所有节点执行 
update_system         # 所有节点执行 
install_docker_ce_sdk # 所有节点执行 
install_ansible_kolla # kolla部署节点执行 
kolla_file            # kolla部署节点执行 
Volume_Group          # 只在存储节点执行
kolla_configure       # 导入配置global.yml
kolla_run             # 执行安装all-in-one版
1. 此脚本必须为: /bin/bash运行. 原因:/bin/sh 解析器中没有source命令.
2. 跑完此脚本后宿主机需要: 更改主机名 hostnamectl set-hostname localhost 添加一个网卡 添加磁盘
3. all-in-one环境部署时跑完此脚本, 更改：/etc/kolla/global.yml 配置即可开始部署.
4. all-in-one环境需要更改的配置:
   kolla_base_distro: "ubuntu"
   openstack_release: "yoga"
   kolla_internal_vip_address: "10.0.0.39"
   network_interface: "ens33"
   neutron_external_interface: "ens37"
   enable_haproxy: "yes" 
   多节点部署与ceph对接依旧运行此脚本普通节点运行部分,再手动更改配置文件即可.\033[0m"
sleep 10
# 设置允许 root 登录
# sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
software_source() {
echo -e "\033[36m 所有节点执行 开始换源 \033[0m"
sleep 2
cp /etc/apt/sources.list /etc/apt/sources.list.bakcup
cat > /etc/apt/sources.list << eric
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
# deb https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
eric
apt update
[ $? = 0 ] && echo -e "\033[36m 换源成功 \033[0m" || echo -e "\033[32m 换源失败 \033[0m"
}
kolla_kvm(){
   # 所有机器执行-宿主机安装kvm
   echo -e "\033[36m 所有机器执行-宿主机安装kvm \033[0m"
   sudo apt update
   kolla_app="qemu qemu-system qemu-kvm virt-manager bridge-utils vlan"
   apt install -y ${kolla_app}
   [ $? = 0 ] && echo -e "\033[36m  宿主机安装kvm安装成功 \033[0m" || echo -e "\033[32m kvm安装失败 \033[0m"
}
update_system() {
   # 所有节点执行
   echo -e "\033[36m 所有节点执行-开始更新系统包 \033[0m"
   system_app="ssh vim git python3-dev libffi-dev gcc libssl-dev"
   apt -y update && apt -y full-upgrade
   apt -y install ${system_app}
   [ $? = 0 ] && echo -e "\033[36m 系统包更新完成 \033[0m" || echo -e "\033[32m 系统包更新失败 \033[0m"
}
install_docker_ce_sdk() {
docker_status=`systemctl status docker |awk 'NR==3{print $2$3}'`
if [ ${docker_status} = "active(running)" ];
then
   echo -e "\033[36m docker-ce安装成功并成功运行: ${docker_status} \033[0m"
else
   # 所有机器执行部分
   echo -e "\033[36m 安装必要的一些系统工具 安装docker-ce docker_sdk 所有机器执行部分! \033[0m"
   docker_app="apt-transport-https ca-certificates curl software-properties-common"
   sudo apt-get -y install ${docker_app}
   [ $? = 0 ] && echo -e "\033[36m 系统工具安装完成 \033[0m" || echo -e "\033[32m 系统工具安装失败 \033[0m"
   echo -e "\033[36m 安装GPG证书 \033[0m"
   curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
   echo -e "\033[36m 写入软件源信息 \033[0m"
   sudo add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
   sudo apt-get -y update
   sudo apt-get -y install docker-ce
   systemctl enable docker && systemctl start docker
   [ $? = 0 ] && echo -e "\033[36m docker-ce安装完成 \033[0m" || echo -e "\033[32m docker-ce安装失败 \033[0m"
   echo -e "\033[36m 安装Docker SDK \033[0m"
   sdk_app="sshpass python3-dev libffi-dev gcc libssl-dev python3-pip python3-venv"
   apt -y install ${sdk_app}
   pip3 install docker -i ${source_pip}
   [ $? = 0 ] && echo -e "\033[36m docker-sdk安装完成 \033[0m" || echo -e "\033[32m docker-sdk安装失败 \033[0m"
fi
}
install_ansible_kolla() {
# 只在kolla部署节点执行-生成虚拟化环境
echo -e "\033[36m 生成虚拟环境安装ansible kolla-ansible14.0 只在kolla部署节点执行! \033[0m"
python3 -m venv ~/venv3
source /root/venv3/bin/activate
pip install -U pip wheel setuptools -i ${source_pip}
# 安装ansible
pip install 'ansible>=4,<6' -i  ${source_pip}
# 新增一个配置文件，让ansible不要检查known host key
touch ~/ansible.cfg
cat > ~/ansible.cfg << eric
[defaults]
host_key_checking=False
pipelining=True
forks=100
eric
# 供github上下载kolla-ansible，yoga分支
pip install kolla-ansible==14.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple
# 安装Ansible Galaxy依赖
cd ~  # 这一步cd为了让当前目录有ansible.cfg
kolla-ansible install-deps
[ $? = 0 ] && echo -e "\033[36m 生成虚拟化环境+ansible kolla-ansible安装完成 
\033[0m" || echo -e "\033[32m ansible kolla-ansible安装失败 \033[0m"
}
Volume_Group() {
    # 只在存储节点执行
    # storage节点上创建一个500GB的VG
    echo -e "\033[36m 只在存储节点执行-需要存储为ceph存储时参考上篇T版部署 \033[0m"
    volume_disk="/dev/vdb /dev/vdc"
    apt -y install lvm2
    pvcreate ${volume_disk}
    vgcreate cinder-volumes ${volume_disk}
}
kolla_file() {
# 只在kolla部署节点执行
# 创建kolla配置文件
echo -e "\033[36m 只在kolla部署节点执行-创建kolla配置文件 \033[0m"
mkdir -p /etc/kolla
chown -R $USER:$USER /etc/kolla
cp ~/venv3/share/kolla-ansible/ansible/inventory/* ~/
cp -r ~/venv3/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
ls ~
ls /etc/kolla
# 两个文件globals.yml  passwords.yml
# 生成密码
kolla-genpwd
[ $? = 0 ] && echo -e "\033[36m 创建kolla配置文件,复制kolla文件到:/etc/kolla,生成密码完成. 
\033[0m" || echo -e "\033[32m 创建kolla配置文件,复制kolla文件到:/etc/kolla,生成密码失败 \033[0m"
# 生成的密码会自动写入/etc/kolla/passwords.yml
# 编写配置模板
# cat << EOF > /etc/kolla/globals.yml 
# ---  
# kolla_base_distro: "ubuntu"
# kolla_install_type: "source" #使⽤基于源代码的image  
# openstack_release: "yoga" #该配置项最好与kolla-ansible分⽀版本保持⼀致
# kolla_internal_vip_address: "10.0.0.250" # 找一个网段内没有占用的ip
# # docker_registry: "10.0.0.203:5000" #指定私有registry  
# network_interface: "enp1s0"  # 内部openstack管理网段
# neutron_external_interface: "enp6s0"  
# enable_haproxy: "yes"
# enable_cinder: "yes"  # 这一个是启动cinder块存储并使用我们的VG
# enable_cinder_backend_lvm: "yes" 
# nova_compute_virt_type: "qemu" #使⽤虚拟机部署时，该配置项必须改为qemu，默认值为kvm  
# EOF
}
kolla_configure() {
echo -e "\033[36m 开始导入hosts以及global.yml配置 \033[0m" 
hoatname_ip=`hostname -I |awk '{print $1}'`
cp /etc/kolla/globals.yml{,.bak}
cat > /etc/kolla/globals.yml << eric
kolla_base_distro: "ubuntu"
openstack_release: "yoga"
kolla_internal_vip_address: "10.0.0.39"  # 找一个网段内没有占用的ip
network_interface: "ens33"
neutron_external_interface: "ens37"
enable_haproxy: "yes" 
nova_compute_virt_type: "qemu"    # 使⽤虚拟机部署时，该配置项必须改为qemu，默认值为kvm
#kolla_install_type: "source"     # 使⽤基于源代码的image
#enable_cinder: "yes"             # 这一个是启动cinder块存储并使用我们的VG
#enable_cinder_backend_lvm: "yes"
eric
cat > /etc/hosts << eric
${hoatname_ip}  localhost
eric
[ $? = 0 ] && echo -e "\033[36m 导入hosts以及global.yml配置成功 \033[0m" || echo -e "\033[32m 导入hosts以及global.yml配置失败 \033[0m"
}
kolla_run() {
cd ~ && source /root/venv3/bin/activate
kolla-ansible -i ./all-in-one bootstrap-servers # 环境安装，这一步会自动安装docker
echo -e  "\033[32m #########################################################  \033[0m"
kolla-ansible -i ./all-in-one prechecks         # 参数预检查
sleep 5
echo -e "\033[32m #########################################################  \033[0m"
kolla-ansible -i ./all-in-one pull              # 下载openstack各个组件容器镜像
echo -e "\033[32m #########################################################  \033[0m"
kolla-ansible -i ./all-in-one deploy            # 部署
echo -e  "\033[32m #########################################################  \033[0m"
kolla-ansible -i multinode  post-deploy         # 生成密钥文件
cp /etc/kolla/admin-openrc.sh  /root
# 遇到报错，销毁已安装的环境
# kolla-ansible -i ./all-in-one destroy --yes-i-really-really-mean-it
[ $? = 0 ] && echo -e "\033[36m openstack:all-in-one版本部署成功,浏览器访问ip:${hoatname_ip}:80
 \033[0m"  || echo -e "\033[32m openstack:all-in-one版本部署失败 \033[0m"
}
main() {
software_source        # 所有节点执行
#kolla_kvm             # 暂不执行执行后会出现报错（所有节点执行）
update_system         # 所有节点执行
install_docker_ce_sdk # 所有节点执行
install_ansible_kolla # kolla部署节点执行
kolla_file            # kolla部署节点执行
#Volume_Group         # 只在存储节点执行 
kolla_configure       # 导入配置global.yml
kolla_run             # 执行安装all-in-one版此处建议手动执行
}
main

