# Download CTS

installStartTime=`date +%s`

cd /tmp

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

mkdir -p /root/cts

cd /root

apt install -y android-sdk-platform-tools unzip sdkmanager openjdk-11-jre

# TODO (gleichda): should be variables
sdkmanager "platforms;android-34" "build-tools;34.0.0"
export PATH=$PATH:/opt/android-sdk/build-tools/34.0.0/

# wget --quiet https://dl.google.com/dl/android/cts/android-cts-13_r5-linux_x86-x86.zip

gsutil cp gs://${bucket_name}/android-cts.zip .

cd /root/cts
unzip ../android-cts.zip

# Start ADB Daemon
adb devices

echo "wait 2 min to make sure that all devices started sucessfully"

sleep 120

%{ for addr in ip_addrs ~}
adb connect ${addr}:${port}
%{ endfor ~}

ctsStartTime=`date +%s`

echo "starting cts-tradefed logs can be found at /root/cts/cts-tradefed.log"
/root/cts/android-cts/tools/cts-tradefed run commandAndExit cts --shard-count ${shard_count} --abi=x86_64 1> /root/cts/cts-tradefed.log
echo "cts-tradefed exited with exit code $${?}"

ctsStopTime=`date +%s`

gsutil -m cp -r /root/cts/android-cts/results/*/ gs://${bucket_name}/results/${build_id}/

copyStopTime=`date +%s`

# TODO (gleichda): Maybe cloud monitoring metrics for duration
echo "Installation took $((ctsStartTime-installStartTime)) seconds"
echo "CTS took $((ctsStopTime-ctsStartTime)) seconds"
echo "Uploading results took $((copyStopTime-ctsStopTime)) seconds"
echo "Overall execution took $((copyStopTime-installStartTime)) seconds"

echo "$(date): Test sucessfully executed triggering destroy of the infrastructure"
gcloud pubsub topics publish build-events --message='{"imagePath":"${image_path}"}'
