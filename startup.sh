sudo apt update;
sudo apt -y install tmux git openjdk-17-jre;

mkdir /server;
mount /dev/sdb /server;

if ! grep -qs '/server ' /proc/mounts; then
    echo "Disk invalid!";
    mkfs.ext4 /dev/sdb;
    mount /dev/sdb /server;
else
    echo "Disk valid!";
fi

if [[ ! -d "/server/minecraft-server" ]]; then
    echo "Minecraft server not existing!";
    cd /server;
    git clone https://github.com/invermn/minecraft-server;
fi

tmux new -d -s server "cd /server/minecraft-server; java -jar -Xmx6G -Xms4G server.jar nogui";
