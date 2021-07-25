#!/bin/bash

### Boot VM with data disk at least 4TB; stop VM; Set sys disk as 500G; start VM; SSH

## mount data disk
sudo parted /dev/sdc --script mklabel gpt mkpart xfspart xfs 0% 100%
sudo mkfs.xfs /dev/sdc1
sudo partprobe /dev/sdc1
sudo mkdir /data
sudo mount /dev/sdc1 /data
sudo chmod 777 /data/
uuidstr=$(blkid | grep /dev/sdc1 | awk -F " " '{print $2}' | awk -F= '{print $2}' | sed 's/"//g')
cat <<EOF | sudo tee -a /etc/fstab
UUID=$uuidstr /data xfs defaults, nofail 1 2
EOF
lsblk -o NAME,HCTL,SIZE,MOUNTPOINT | grep -i "sd"

## install anaconda 
sudo yum install -y libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver
wget https://repo.anaconda.com/archive/Anaconda3-2021.05-Linux-x86_64.sh
chmod +x Anaconda3-2021.05-Linux-x86_64.sh
sudo bash ./Anaconda3-2021.05-Linux-x86_64.sh
cat <<EOF | sudo tee -a /etc/profile
export PATH=\$PATH:/opt/anaconda3/bin
EOF
source /etc/profile

## Get repo and build 
cd /data
git clone https://github.com/RosettaCommons/RoseTTAFold.git
cd RoseTTAFold
conda env create -f RoseTTAFold-linux.yml
conda env create -f folding-linux.yml
conda env list
./install_dependencies.sh

conda init bash
source /home/azureuser/.bashrc
conda activate folding
wget https://proteinfoldonazure.blob.core.windows.net/data/PyRosetta4.Release.python37.linux.release-289.tar.bz2
tar -vjxf PyRosetta4.Release.python37.linux.release-289.tar.bz2 
cd PyRosetta4.Release.python37.linux.release-289/setup
python setup.py install
#verify the pyrosetta lib
python   
#then input two lines: import pyrosetta;   pyrosetta.init()
#Ctrl-D to go back
conda deactivate

cd /data/RoseTTAFold/
## wget https://files.ipd.uw.edu/pub/RoseTTAFold/weights.tar.gz
wget https://proteinfoldonazure.blob.core.windows.net/data/weights.tar.gz
tar -zxvf weights.tar.gz

## uniref30 [46G]
## wget http://wwwuser.gwdg.de/~compbiol/uniclust/2020_06/UniRef30_2020_06_hhsuite.tar.gz
wget https://proteinfoldonazure.blob.core.windows.net/data/UniRef30_2020_06_hhsuite.tar.gz
mkdir -p UniRef30_2020_06
tar -zxvf UniRef30_2020_06_hhsuite.tar.gz -C ./UniRef30_2020_06

## BFD [272G]
## wget https://bfd.mmseqs.com/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz
wget https://proteinfoldonazure.blob.core.windows.net/data/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz
mkdir -p bfd
tar -zxvf bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz -C ./bfd

## structure templates (including *_a3m.ffdata, *_a3m.ffindex) [over 100G]
## wget https://files.ipd.uw.edu/pub/RoseTTAFold/pdb100_2021Mar03.tar.gz
wget https://proteinfoldonazure.blob.core.windows.net/data/pdb100_2021Mar03.tar.gz
tar -zxvf pdb100_2021Mar03.tar.gz

### Run sample
# For monomer structure prediction
cd example
../run_pyrosetta_ver.sh input.fa .

mv t000_.3track.npz t000_.3track.npz.origin
../run_e2e_ver.sh input.fa .