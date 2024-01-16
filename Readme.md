## 一些命令行常用脚本和配置工具

### 一、命令行自动补全插件
#### 先安装 oh my zsh
> sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#### 执行安装脚本
> git clone --branch v0.6.4 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && curl https://raw.githubusercontent.com/htprimer/mac_toolchain_configs/master/myStrategy.zsh >> $ZSH_CUSTOM/myStrategy.zsh && echo 'plugins+=(zsh-autosuggestions)\nsource $ZSH/oh-my-zsh.sh' >> ~/.zshrc && source ~/.zshrc
