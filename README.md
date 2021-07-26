# proteinfold-on-azure

## RoseTTAFold on Azure (Single VM)
### Prerequisites

· Read and know the license requirements of [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold/blob/main/LICENSE) and its [weight data](https://files.ipd.uw.edu/pub/RoseTTAFold/Rosetta-DL_LICENSE.txt).  
· Apply for [PyRosetta License](https://els2.comotion.uw.edu/product/pyrosetta) and [download](http://www.pyrosetta.org/downloads) installation package file (suggest Python3.7 Linux version).   
· Have or [register a new Azure cloud account](https://www.microsoft.com/china/azure/index.html).  
· Create [SSH Key](https://docs.microsoft.com/en-us/azure/virtual-machines/ssh-keys-portal) and save the pem file.  
· Select the working Azure region (suggest US West 2 region). [Create Resource Group](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#:~:text=1%20Sign%20in%20to%20the%20Azure%20portal.%202,newly%20created%20resource%20group%20to%20open%20it.%20) and [Create a Vnet](https://docs.microsoft.com/en-us/azure/virtual-network/quick-create-portal).  
· Submit NCas_T4_v3 [quota increate request](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests) of Azure T4 GPU Series VM. If need more performance, request the V100 series NCs_v3 quota instead.  
· This hands-on will charge cost. Here is a reference if use T4 VM in US West 2 region: less than $50 estimated 1 day accomplishment. Detailed pricing is [here](https://azure.microsoft.com/en-us/pricing/calculator/?service=virtual-machines).   
Let's move on after above prerequisites confirmed.
 
### Start VM
In Azure console,  enter the VM creating page by Home->Create Resource->Virtual Machine. Set the basic configuration as below screenshot shows. Set VM size as NC16as_T4_v3 and image as CentOS-based HPC 7.9 Gen2 with GPU driver, CUDA and HPC tools pre-installed. Set SSH Key as created before.

![image](https://github.com/Iwillsky/proteinfold-on-azure/blob/main/images/configvm.jpg)

Click Next:Disks. Config a new data disk by click 'Create and attach a new disk'. Suggest at least 4096GB with consideration of training dataset amount. Click 'Review+Create' to check and then Create VM.

![image](https://github.com/Iwillsky/proteinfold-on-azure/blob/main/images/configdatadisk.jpg)

We need one more step to enlarge the system disk size. Stop VM first with click option of reserve VM's public IP address. After status is as stopped, click VM Disk menu -> click system disk link -> 'Size+performance' to set the system disk size as 512G and performance tier P20 or higher as below shows. Wait till upper right pop-up info shows update accomplished then go back to Start the VM. VM status will change to Running several minutes later.

![image](https://github.com/Iwillsky/proteinfold-on-azure/blob/main/images/configosdisk.jpg)

SSH login to VM server and execute the next commands to mount data disk to VM. 

```
sudo parted /dev/sdc --script mklabel gpt mkpart xfspart xfs 0% 100%
sudo mkfs.xfs /dev/sdc1
sudo partprobe /dev/sdc1
sudo mkdir /data
sudo mount /dev/sdc1 /data
sudo chmod 777 /data
uuidstr=$(blkid | grep /dev/sdc1 | awk -F " " '{print $2}' | awk -F= '{print $2}' | sed 's/"//g')
cat <<EOF | sudo tee -a /etc/fstab
UUID=$uuidstr /data xfs defaults, nofail 1 2
EOF
lsblk -o NAME,HCTL,SIZE,MOUNTPOINT | grep -i "sd"
```

### RoseTTAFold installation & Data preparation 
Keep in SSH console and execute below commands to install the RoseTTAFold application, which include these steps:
· Install Anaconda3. In process set the destination directory as /opt/anaconda3 and select yes when ask whether to init conda.  
· Download RoseTTAFold Github repo.  
· Config two conda environments.  
· Install the PyRosetta4 component in folding conda environment.  
```	 
## Install anaconda 
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
python     #To verify the pyrosetta lib in python commandline
#then input two commands:     import pyrosetta;    pyrosetta.init()
conda deactivate
```

During above steps, enter Python command to check the status of PyRosetta4 after setup.py install action. Execute the command of import and the init() to check as without any compilation errors. This point is very important to confirm before goto the next.

```
(folding) [azureuser@vmt4rosettarun RoseTTAFold]$ python
Python 3.7.10 (default, Jun  4 2021, 14:48:32) 
[GCC 7.5.0] :: Anaconda, Inc. on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import pyrosetta;
>>> pyrosetta.init()
PyRosetta-4 2021 [Rosetta PyRosetta4.Release.python37.linux 2021.27+release.7ce64884a77d606b7b667c363527acc846541030 2021-07-09T18:10:05] retrieved from: http://www.pyrosetta.org
(C) Copyright Rosetta Commons Member Institutions. Created in JHU by Sergey Lyskov and PyRosetta Team.
core.init: Checking for fconfig files in pwd and ./rosetta/flags
core.init: Rosetta version: PyRosetta4.Release.python37.linux r289 2021.27+release.7ce6488 7ce64884a77d606b7b667c363527acc846541030 http://www.pyrosetta.org2021-07-09T18:10:05
core.init: command: PyRosetta -ex1 -ex2aro -database /home/azureuser/.conda/envs/folding/lib/python3.7/site-packages/pyrosetta-2021.27+release.7ce6488-py3.7-linux-x86_64.egg/pyrosetta/database
basic.random.init_random_generator: 'RNG device' seed mode, using '/dev/urandom', seed=-2055557650 seed_offset=0 real_seed=-2055557650
basic.random.init_random_generator: RandomGenerator:init: Normal mode, seed=-2055557650 RG_type=mt19937
>>> 
Press Ctrl+D and execute 'conda deactivate' to go back to VM shell.
```

Next is to prepare the datasets including weights and reference protein pdb database. We duplicate these data in Azure Blob storage to fasten the download speed due to theire large data amount. Unzip operation will cost some time in hours. Suggest to unzip in multiple SSH windows with no interruption to assure the data integerity. Check the data size through 'du -sh <dirname>' command as bfd 1.8TB/pdb100 667GB/UniRef30 181GB.

```
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
```
	
### Running sample 
Then we can run the RoseTTAFold: (Do not lose the second param of '.' )
```
cd example
../run_pyrosetta_ver.sh input.fa .
```
First running will execute the generation of MSA params and execute Hhsearch, which will cost some time est. at ~30 mins. Successful running prompts like below and will output 5 preferred protein pdb results at path of example/model/ which named as model_x.pdb. AI training logging info can be found at ./log/folding.stdout. 
```
[azureuser@vmt4rosettarun example]$ ../run_pyrosetta_ver.sh input.fa .
Running HHblits
Running PSIPRED
Running hhsearch
Predicting distance and orientations
Running parallel RosettaTR.py
Running DeepAccNet-msa
Picking final models
Final models saved in: ./model
Done 
```
	
And you can also try a end-to-end prediction by executing below commands, which will be done within 10 mins. At example/ path, it will output t000_.e2e.pdb result.

```	
mv t000_.3track.npz t000_.3track.npz.origin
../run_e2e_ver.sh input.fa .
```

GPU utilization reached near 100% in prediction steps as below screenshot shows. If want to use more CPU and memory in execution, modify the 18th line of run_pyrosetta_ver.sh and run_e2e_ver.sh with more CPU number and memory size for full utilization of infrastructure resource.

![image](https://github.com/Iwillsky/proteinfold-on-azure/blob/main/images/gpu-util.jpg)
	
Below is the image of two pdb protein structure of pyrosetta and end2end results in PyMOL tools UI. What to do in the next is to change the input fa file as yours or to write your own script according these two demos.

![image](https://github.com/Iwillsky/proteinfold-on-azure/blob/main/images/pdb_result.jpg)

### Tear down
If will not keep this enviroment, delete the resource group to tear down all the related resource directly.
