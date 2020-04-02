cd
apt update
apt install -y --no-install-suggests --no-install-recommends lib32stdc++6 git tar python python-pip lrzsz wget
SMVERSION=1.9
git clone https://github.com/RoyZ-CSGO/csgo-practice-mode-zh-CN
cd csgo-practice-mode-zh-CN
git submodule update --init --recursive
git clone https://github.com/splewis/sm-builder
cd sm-builder
pip install --user -r requirements.txt
python setup.py install
cd ..
SMPACKAGE="http://sourcemod.net/latest.php?os=linux&version=${SMVERSION}"
wget $SMPACKAGE
tar xfz $(basename $SMPACKAGE)
cp scripting/include/dhooks.inc addons/sourcemod/scripting/include
cp scripting/include/botmimic.inc addons/sourcemod/scripting/include
cd addons/sourcemod/scripting/
chmod +x spcomp
PATH+=":$PWD"
cd include
wget https://raw.githubusercontent.com/splewis/csgo-pug-setup/master/scripting/include/pugsetup.inc
wget https://raw.githubusercontent.com/splewis/get5/master/scripting/include/get5.inc
wget https://bitbucket.org/GoD_Tony/updater/raw/12181277db77d6117052b8ddf5810c7681745156/include/updater.inc
git clone https://github.com/bcserv/smlib
cp -r smlib/scripting/include/* .
cd ../../../..
cd scripting/practicemode
rm -f commands.sp
wget https://raw.githubusercontent.com/splewis/csgo-practice-mode/master/scripting/practicemode/commands.sp
cd
cd csgo-practice-mode-zh-CN
smbuilder
tar zcvf /built/build.tar.gz builds
