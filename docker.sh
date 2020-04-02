wget https://raw.githubusercontent.com/kotori-bgt/csgo-practice-mode-zh-CN/master/build.sh -O /root/build.sh
chmod +x build.sh
docker run --name ubuntu --rm -v /root:/built ubuntu:bionic /bin/bash -c "/built/build.sh" 
