### Zabbix Template Module SMB version 1.0.3

Tested on Zabbix 4.0 to 5.2

# Introduction
Template for zabbix to check smb share availability using external script.
It can check:
* If SMB shares are available
* SMB shares rights

The script will be launched by Zabbix server, testing if client SMB share is available using a script.
That mean Zabbix network must be able to see SMB sharing of the client on the network.
* All the files are installed on Zabbix server, none is required on the client.
* Your network must allow zabbix server to communicate with SMB share of the client

# Requirement
The script use the commands **smbclient** so it requires the linux package **smbclient** on your zabbix server

To install it you can use the package manager of your distribution

Exemple
```bash
apt-get install smbclient
```
By the way you may require sudoer rights to run the command.

# Installation

## Content
The template installation require 2 files:
* **frogg_smb_check.sh** Zabbix external script
* **frogg_smb_check.xml** Zabbix template configuration

## External script

You need to place the script **frogg_smb_check.sh** into zabbix external forlder **externalscripts** (by default in **/usr/lib/zabbix/externalscripts**) 

You can find the external script folder in Zabbix configuration file **zabbix_server.conf** (by default in **/etc/zabbix/zabbix_server.conf**)

You will need to add execute permission on the script
```bash
chmod +x frogg_smb_check.sh 
```

### Testing the installation
You can run the command:
- To Test SMB shares (check only the exposed share, so it test only root share folder)
```bash
./frogg_smb_check.sh share 192.168.0.1 "frogg$,hd,uhd,series,shows,musics"
```
- To Test SMB rights (can check for subfolder if separated with /)
```bash
./frogg_smb_check.sh right 192.168.0.2 "frogg$|frogg:pass+w,frogg$+n,series+w,uhd+w,hd+w,shows+w,musics+w,temp+r,temp/subfolder|user:pass+w"
```
## Template

Then you need to import the **frogg_smb_check.xml** template configuration file in the zabbix web interface in **Template** tab using the import button

# Host configuration
The template use 2 macros :

MACRO | Description
----- | -----------
{$SMBSHARES} | the list of SMB shares that should be available, to set multiple shares they must be separated by **,**
{$SMBRIGHTS} | the list of SMB shares with user and rights, to set multiple shares they must be separated by **,**

Exemple:
![Zabbix SMB configuration sample](https://tool.frogg.fr/upload/github/zabbix-smb/macros-1.0.3.png)

RIGHT | Description
----- | -----------
+n | should have no permission (trigger error if can read)
+r | should have read permission only (trigger error if can write)
+w | should have write permission

## More about rights & shortchuts
format = SHARENAME|USER:PASS+RIGHT
* if USER is not set, script try to log in the SMB share anonymously
* if RIGHT is not set, script try READ permission

Exemple:
* SHARE|USER:PASS is a shortcut  to SHARE|EUSER:PASS+r
* SHARE is a shortcut to SHARE|anonymous+r
* SHARE+n is a shortcut to SHARE|anonymous+n

## More about shares
* For the share test
It check only if main folder are shared so you can put subfolder there
* For the share rights
Share can include sub folder, but they need to be separated by **/** and not by **\\**

Exemple:
 * SHARE/SUBFOLDER/SUBFOLDER/EVENMORE|USER:PASS+r
 * SHARE/SUBFOLDER/EVENMORE+w

# Template items
![Zabbix SMB Template](https://tool.frogg.fr/upload/github/zabbix-smb/items-1.0.3.png)

# Template triggers
![Zabbix SMB Template triggers](https://tool.frogg.fr/upload/github/zabbix-smb/triggers-1.0.3.png)

# Debuging

Going further...This step is working with most of externals scripts

If you got troubles getting an external script working, first :
1. Check the Zabbix tab **Monitoring > lastest data**
If you select an host, you should see all items linked to it, check for your item and you should see the lasted data linked to it.
If it appear in gray (disabled) that mean there is something wrong with the external script (rights, path, arguments ...)
To find more about it you can check logs
2. By default the logs are in **/var/log/zabbix/zabbix_server.log** or you can find the log path in Zabbix configuration file **zabbix_server.conf** (by default **/etc/zabbix/zabbix_server.conf**)

To get the last log lines you can use for example:
```bash
tail -f /var/log/zabbix/zabbix_server.log
```
Then look at the script trouble...

Example:
![Zabbix NFS error sample](https://tool.frogg.fr/upload/github/zabbix-nfs/error.png)
In this case Zabbix cannot find the path of the script as you can see *no such file or directory*
