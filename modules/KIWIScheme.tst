<!-- TEST XML SCHEME FOR KIWI -->

<image name="bob">

	<description type="boot">
		<author>Marcus Schaefer</author>
		<contact>ms@novell.com</contact>
		<specification>Boot/initrd image used for PXE</specification>
	</description>

	<preferences>
		<type>ext3</type>
		<version>1.2.3</version>
		<size unit="M">460</size>
		<rpm-check-signatures>False</rpm-check-signatures>
		<packagemanager>smart</packagemanager>
	</preferences>

	<users group="users">
		<user name="linux" pwd="$2a$10$90AjhfXU2YIwTRrIftBauecvWXVuaNZ6JLM2IpWi0svu2kO16le9e" home="/home/linux"/>
	</users>

	<drivers type="drivers">
        <file name="drivers/ide/*"/>
	</drivers>

	<repository type="yast2" status="fixed">
		<source path="/image/dist/full-10.2-i386"/>
	</repository>

	<deploy server="192.168.1.1" blocksize="4096">
		<partitions device="/dev/sda">
			<partition type="swap" number="1" size="1000"/>
			<partition type="L" number="2" size="10000" mountpoint="/"/>
			<partition type="fd" number="3"/>
		</partitions>
		<configuration source="bla1" dest="blub1"/>
		<configuration source="lala" dest="/etc/lala"/>
    </deploy>

	<packages type="image" patternType="onlyRequired">
		<package name="libgnomesu"/>
		<package name="ICAClient"/>
		<opensusePattern name="default"/>
	</packages>

	<packages type="xen" memory="128" disk="/dev/sda">
		<package name="kernel-xen"/>
		<package name="xen"/>
	</packages>

	<packages type="boot">
		<package name="filesystem"/>
		<package name="glibc-locale"/>
		<package name="devs"/>
		<package name="rpm"/>
	</packages>

</image>
