This is taken from the bootpins test for the netx 90, release v1.3.8.
https://github.com/muhkuh-sys/org.muhkuh.tests-bootpins

It is used by the detect_netx command of the CLI flasher when
the chip type netX 90 Rev1 is detected in order to discriminate
between this chip type and the netX 90 Rev1 with PHY V3.

This version is from the branch "cli_flasher".
It skips the ethernet initialization when it is used via romloader_eth.
bootpins.lua has been edited to make it comaptible with the CLI flasher environment.


