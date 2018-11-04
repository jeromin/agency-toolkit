# agency-toolkit
This little tool is used to help with websites management [@Weedo.Agency](https://weedo.agency).

It uses SSH conneciton to backup a remote folder and a mysql database.
Then it creates an archive which will be sent to a bucket on Google Storage or Amazon S3.

*I choosed to download the whole site in a temp folder in case the disk space on remote isn't enough.*

## Installation

⚠ **Warning:** If you want to give these tool a try, you should first review the code. Don’t blindly use it unless you know what that entails. Use at your own risk!

You can clone the repository wherever you want.

```bash
git clone https://github.com/jeromin/agency-toolkit.git && cd agency-toolkit
```

Simply `./toolkit.sh` to test it out.

Don't forget to give your user execute permission `chmod u+x ./toolkit.sh`

![Preview of the toolkit usage](https://i.imgur.com/Go3kpik.png)

### Symlink

`./toolkit.sh link` to symlink inside `/usr/local/bin` folder.

If your prefer to use your own command name for better convenience, you can directly symlink the toolkit, using:

```bash
./toolkit.sh link weedo
```

## ⚙️ Configuration

Try any listed command or use `configure` option to begin.
It will create a file in your `$HOME` folder, containing your private credentials.

So, go ahead and copy or edit that file if your prefer.
Here is an [example](.example).

To upload the archive on a bucket, the script uses native command `gsutil`, `aws s3` or `s3cmd`.

*For website without SSH you can specify the __SCP__ protocol, but `mysqldump` won't work.*

## How to use it

Once your bucket and a first website are configured, you can run:

```bash
./toolkit.sh backup website 	# Backup everything
```

You can automate with `crontab` :

```cron
0 3 1 * * sh toolkit.sh backup disk site	# Backup the site each month at 3am
0 3 * * * sh toolkit.sh backup mysql site	# backup the database every day at 3am
```

Here are the other commands:

* `ls [site]`					: List all the websites available
* `backup [disk|mysql] site`	: Start the backup sequence
* `connect site`				: Establish an ssh connection to the remote server
* `run site command`			: Run a command on the remote server
* `bucket [site]`				: List the bucket content
* `key create|copy [site]`		: Create SSH key and authorized it on remote
* `test [disk|mysql] site`		: Check the backup functionnality 
* `link|unlink [name]`			: Link or unlink the command
* `configure|help`				: Configure the toolkit or a new website

## Feedback

Feel free to use or [contribute](https://github.com/jeromin/agency-toolkit/issues)!

