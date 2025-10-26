
# Rzync Backup

High-performance parallel backup solution using rsync and ZFS snapshots.

**An optimized fork of [Adlibre Backup](https://github.com/adlibre/adlibre-backup)** focusing on ZFS-only usage,  
parallel execution, and enhanced operational features.

Designed with system administrators in mind.

## What's Different from Adlibre Backup

* **ZFS-only**: BTRFS support removed, focusing exclusively on ZFS performance and features
* **Parallel Execution**: Run multiple backups concurrently with `backup-runner-parallel.sh`
* **Flexible Post-Backup Hooks**: Configurable `BACKUP_POST_HOOK` with `--skip-post-hook` option
* **Enhanced Monitoring**: Multiple NSCA servers, configurable service names, improved logging
* **Helper Scripts**: SSH fingerprint management, age-based pruning, monitoring diagnostics
* **Better Exit Codes**: Differentiation between success (0), partial success (2), and failure

Utilises native ZFS filesystem features for seamless compression,  
deduplication and snapshoting of the backup pool.

#### Why the fork

While the Adlibre-Backup worked great and has proved to be stable for many years, it lacked parallel execution and sending monitoring data to multiple hosts at once. It also hasn't been updated in 7+ years. We think it's a great tool, that only needed a little overhaul.

#### Our solution

This fork is actively maintained and has been running in production for almost a decade, backing up 100+ servers each day, with replication (Syncoid) and monitoring (CheckMK). Since we only use ZFS on our backup machines, we removed the BTRFS-Code, to make the code cleaner and easier to maintain.

### Aims

* High performance and scalability. (Benchmarked faster than other Rsync backup  
  solutions. eg BackupPC, Rsnapshot etc.)
* Simplicity: Simple text based configuration. And simple files-on-disk  
  backup format.
* Aims to be a paranoid system administrator's best friend.

### Features

* Agentless
* Utilises ZFS filesystem features, eg snapshot, dedup and compression
* **Parallel backup execution** with configurable concurrency level
* Uses [Rsync](http://en.wikipedia.org/wiki/Rsync) and  
  [SSH](http://en.wikipedia.org/wiki/OpenSSH) for transport
* **Automatic replication** to remote backup servers using syncoid
* Integration with monitoring tools such as Nagios, Icinga or CheckMK using NSCA passive  
  checks. Or easily integrate your own monitoring system by configuring a  
  `MONITOR_HANDLER` script.
* Centralised configuration and management - all configuration and scheduling is  
  done on the backup server
* Ad hoc annotated backups - allows for ad hoc backups with an explanation as to  
  when or why the backup was taken and per backup retention periods
* Per host backup, retention and quota policies
* Per host configuration and logs stored with the snapshot
* **Helper scripts** for SSH key management and snapshot pruning

## Installation

High level installation is as follows:

1. An operating system with ZFS support is required (eg  
   [FreeBSD](http://www.freebsd.org) or [ZFS on Linux](http://zfsonlinux.org/))  
   and a dedicated storage pool.

2. Check out the source code into the root of your `/backup` pool storage device  
   and review ``./etc/backup.conf``. Modify as necessary to set your pool and  
   filesystem options, especially the `CONCURRENCY` parameter for parallel execution.

3. (Optional) Install [sanoid](https://github.com/jimsalterjrs/sanoid) for syncoid  
   replication support.

### Detailed: Red Hat / CentOS / EL Installation and ZFS Usage Example

Create _backup_ zpool with dedup and compression.
```bash  
zpool create -f backup vdb zfs set dedup=on backup zfs set compression=gzip backup  
```

Install Rzync Backup into root of _backup_ zpool.
```bash  
yum -y install git 
cd /backup && git clone https://github.com/yourusername/rzync-backup.git .  
```

Install NSCA Client (optional) for Nagios / Icinga / CheckMK integration
```bash  
yum -y install nsca-client  
```

### Detailed: Ubuntu / Debian Installation and ZFS Usage Example

Create _backup_ zpool with dedup and compression.
```bash  
zpool create -f backup vdb zfs set dedup=on backup zfs set compression=gzip backup  
```

Install Rzync Backup into root of _backup_ zpool.
```bash  
apt install git 
cd /backup && git clone https://github.com/yourusername/rzync-backup.git .  
```

Install NSCA Client (optional) for Nagios / Icinga / CheckMK integration
```bash  
apt -y install nsca-client  
```



Generate SSH Key, this is used for authentication.
```bash
ssh-keygen -t rsa -N "" -f ~root/.ssh/id_rsa  
```

Add _server.example.com_ host config and copy the SSH Key to host example.com
```bash
cd /backup && ./bin/add-host.sh example.com  
```

Now run the backup
```bash

./bin/backup-runner.sh --all  
```

The output
```bash

[root@zbackup backup] ./bin/backup-runner.sh --all 
Info: Begin backup run of hosts example.com Info: 
Begining backup of example.com 
Running: rsync -a --numeric-ids --hard-links --compress --delete-after --delete-excluded --fuzzy --exclude=/dev --exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/var/tmp --exclude=/var/run --exclude=/selinux --exclude=/cgroups --exclude=lost+found root@example.com:'/' /backup/hosts/example.com/d/ 
Backup Successful. Runtime 1757 seconds.
Snapshot example.com@2013-06-14-15:12:39-1371186759 Created Info: Completed backup of example.com
```
That's it.

Now if you want to schedule daily backups Add the following to your root crontab:
```bash

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin @daily /backup/bin/backup-runner.sh --all --comment "Backup Daily" && /backup/bin/prune.sh --all
```
## Configuration

### Global Configuration (etc/backup.conf)

Key configuration parameters:

* `POOL_NAME`: Name of your ZFS pool (default: `backup`)
* `CONCURRENCY`: Number of parallel backup jobs (default: `4`)
* `RSYNC_ARGS`: Rsync arguments for backup operations
* `EXCLUDE`: Space-separated list of paths to exclude from backups
* `EXPIRY`: Default backup retention in days (default: `90`)
* `MONITOR_ENABLED`: Enable/disable monitoring integration
* `NSCA_SERVERS`: Space-separated list of NSCA monitoring servers
* `BACKUP_POST_HOOK`: Command to execute after all backups complete (e.g., syncoid replication)

Example:
```bash  
POOL_NAME='backup'  
CONCURRENCY=4  # Run 4 backups in parallel  
EXPIRY='90'  
  
# Multiple monitoring servers (space-separated)  
NSCA_SERVERS='monitoring1.example.com monitoring2.example.com'  
  
# Post-backup hook (optional)  
BACKUP_POST_HOOK='/usr/sbin/syncoid -r backup/hosts root@remote:backup/hosts --compress=lz4'  
# Leave empty to disable: BACKUP_POST_HOOK=''  
```  

### Per-Host Configuration

Each host has its own configuration in `./hosts/<hostname>/c/backup.conf` where you can override:
* `RSYNC_HOST`: Alternative hostname or IP for rsync connection
* `RSYNC_ADDITIONAL_ARGS`: Additional rsync arguments (e.g., custom SSH port: `-e 'ssh -p 2222'`)
* `EXCLUDE`: Host-specific exclusions
* `BACKUP_PATHS`: Which paths to backup
* `DISABLED`: Set to `true` to disable backups for this host
* `PRUNE`: Set to `false` to disable automatic pruning

## Usage

### Adding a host

``./bin/add-host.sh <hostname>``

Then customise the per host config in ``./hosts/<hostname>/c/backup.conf`` and  
ssh options in ``~/.ssh/config`` if required.

### Removing a host (ZFS)

To immediately purge the host configuration and all backup data:

``zfs umount zfs-pool-name/hosts/<hostname> &&  
zfs destroy zfs-pool-name/hosts/<hostname>``

To disable future backups and allow existing backups to expire in line with the  
retention policy set _DISABLED=true_ in ``./hosts/<hostname>/c/backup.conf``.  
This is the preferred method for host removal as it allows the old backups to  
naturally expire.

### Running an ad hoc backup of a single host

``./bin/backup.sh <hostname> <annotation> <expiry-in-days>``

### Running a backup of all hosts

Sequential execution:

``./bin/backup-runner.sh --all``

or multiple hosts

``./bin/backup-runner.sh <hostname> <hostname>...``

### Running parallel backups (Recommended)

For improved performance, use the parallel backup runner which executes backups concurrently  
based on the `CONCURRENCY` setting in `etc/backup.conf`:

``./bin/backup-runner-parallel.sh --all --comment "Parallel Daily Backup"``

The parallel runner uses `xargs` to execute multiple backup jobs simultaneously.

Skip the post-backup hook for single-host backups:

``./bin/backup-runner-parallel.sh --skip-post-hook host1.example.com``

### Running scheduled backups with flexible retention
You can configure cron jobs to run regular backups with flexible retentions.

The following example keeps daily backups for 2 weeks, weekly backups for 6 months and monthly backups for a year.

Sequential execution:
```  
# daily backups, kept for 2 weeks  
00 2 2-31 * * test $(date +\%u) != 7 && /backup/bin/backup-runner.sh --all --comment "Daily backup" --expiry 14 && /backup/bin/prune.sh --all  
# weekly backups, kept for 6 months  
00 2 2-31 * * test $(date +\%u) = 7 && /backup/bin/backup-runner.sh --all --comment "Weekly backup" --expiry 180 && /backup/bin/prune.sh --all  
# monthly backups, kept for a year  
00 2 1 * * /backup/bin/backup-runner.sh --all --comment "Monthly backup" --expiry 365 && /backup/bin/prune.sh --all  
```  

Parallel execution (recommended):
```  
# daily parallel backups, kept for 2 weeks  
00 2 2-31 * * test $(date +\%u) != 7 && /backup/bin/backup-runner-parallel.sh --all --comment "Daily backup" --expiry 14 && /backup/bin/prune_oldest.sh --all  
```  

### Helper Scripts

#### SSH Key Management

Automatically scan and add SSH fingerprints for all configured backup hosts:

``./bin/scan-known-hosts.sh``

This script reads each host configuration, extracts the hostname and port, and adds  
SSH fingerprints to `~/.ssh/known_hosts`. Useful for initial setup or after host key changes.

Test SSH connectivity to configured hosts:

``./bin/ssh-test.sh --all``

#### Snapshot Pruning

Alternative pruning script that removes snapshots older than 4 months:

``./bin/prune_oldest.sh --all``

Options:
- `--all` or `-a`: Prune all hosts
- `--dry-run` or `-n`: Show what would be deleted without actually deleting
- `--force` or `-f`: Force pruning even if disabled in host config

Note: This script excludes syncoid snapshots from pruning.

### Restoring (ZFS)

All backups are stored on disk in plain sight. To restore all you need to do  
is copy (or rsync) the files from the backup pool to your host.

To find a particular snapshot:

``./bin/list-backups.sh <hostname>``

eg:

backup-host# ./bin/list-backups.sh example.com example.com 2012-10-25-23:35:19-1351168519 1352377190 successful "first backup" example.com 2012-11-04-15:40:49-1352004049 1354418267 successful "before acme software upgrade"  
The files are stored plainly within the ZFS snapshot:

backup-host# ls -lah /backup/hosts/example.com/.zfs/snapshot total 3 dr-xr-xr-x  4 root  wheel     4B Nov 17 15:14 . dr-xr-xr-x  4 root  wheel     4B Oct 16 20:18 .. drwxr-xr-x  5 root  wheel     5B Oct 16 20:18 2012-10-25-23:35:19-1351168519 drwxr-xr-x  5 root  wheel     5B Oct 16 20:18 2012-11-04-15:40:49-1352004049  
Just dive in and copy the files out of the snapshot:

cd /backup/hosts/example.com/.zfs/snapshot/ && \ rsync -aH --numeric-ids 2012-11-04-15:40:49-1352004049/d/ example.com:/restore-point/
## Upgrading

Upgrading is just a matter of updating the code and merging in any local changes  
to the default configuration. If you're using git to deploy the code then  
`git pull` is usually sufficient.

However from time to time options and features do sometimes change. Please review  
any changes to the defaults in `etc/backup.conf`.

The on disk pool format is stable and no changes are required to support upgrades.

## Credits

Based on [Adlibre Backup](https://github.com/adlibre/adlibre-backup) by Adlibre Pty Ltd.  
Heavily modified and optimized for ZFS-only usage with parallel execution and enhanced operational features.

## Status

Rzync Backup is actively maintained and in production use. The original Adlibre Backup  
codebase has proven stable over many years. This fork maintains that stability while  
adding significant performance and operational improvements.

## License

See [LICENSE](LICENSE) file for details.
