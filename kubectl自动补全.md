~~~ bash
yum install -y bash-completion
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
#如果你是zsh 将bash替换为zsh即可
~~~
