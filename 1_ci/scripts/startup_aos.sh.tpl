set -x

# First Boot
if [ ! -d "/root/android-cuttlefish" ]; then
    cd /root
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    bash add-google-cloud-ops-agent-repo.sh --also-install
    echo "First Boot setting up cuttlefish"
    apt install -y git devscripts config-package-dev debhelper-compat golang curl android-sdk-platform-tools
    git clone https://github.com/google/android-cuttlefish
    cd android-cuttlefish
    for dir in base frontend; do
        cd $dir
        debuild -i -us -uc -b -d
        cd ..
    done
  dpkg -i ./cuttlefish-base_*_*64.deb || sudo apt-get install -f
  dpkg -i ./cuttlefish-user_*_*64.deb || sudo apt-get install -f
  adduser --disabled-password --gecos "" android
  usermod -aG kvm,cvdnetwork,render android
  echo "rebooting now"
  reboot
fi

cd /home/android/

echo "Cuttlefish is already set up; Setting up android device"

# Will be a call to get the custom image later
gsutil cp ${image_path} aosp_cf_x86_64_phone-img.zip
gsutil cp ${host_package_path} cvd-host_package.tar.gz

mkdir cf
cd cf
tar -xvf /home/android/cvd-host_package.tar.gz
unzip /home/android/aosp_cf_x86_64_phone-img.zip

chown --recursive android:android /home/android

cat <<EOF >>/etc/systemd/system/cuttlefish.service
[Unit]
Description=Cuttlefish device
After=network.target

[Service]
User=android
Group=android
Environment=HOME=/home/android/cf/
ExecStart=/home/android/cf/bin/launch_cvd --memory_mb=7168 --cpus=8 --modem_simulator_sim_type=2
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl start cuttlefish.service
