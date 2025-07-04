# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use base "installedtest";
use strict;
use testapi;
use networking;
use serial_terminal qw(select_root_console);


sub run {
    my ($self) = @_;
    select_root_console;

    $self->select_gui_console;

    # Update onion address
    x11_start_program('xterm');

    background_script_run("qvm-run -p sd-dev \"cd securedrop\; sed -i 's|/dev/stdout|/dev/null|g' securedrop/bin/dev-shell && make dev-tor\" </dev/null 2>&1 >/dev/null"); # | sed 's/^/[SD Server] /'"); # grep "journalist interface" so that it does not interfere with needles
    #assert_script_run("tail -f /tmp/securedrop-server.log | grep -m 1 '=> Journalist Interface <='", timeout => 90);
    # wait_serial("=> Journalist Interface <=");
    sleep(60); # wait for onion address to propagate

    # Update onion address
    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting
    assert_script_run('set -o pipefail'); # Ensure pipes fail\
    assert_script_run('export JOURNALIST_ONION=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/hostname")');
    assert_script_run('export JOURNALIST_KEY=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/authorized_clients/client.auth"| cut -d: -f3)');

    # Propagate the new values
    my %vm_config_values = (
        "qvm-features sd-proxy vm-config.SD_PROXY_ORIGIN"  => "\"http://\$JOURNALIST_ONION\"",
        "qvm-features sd-whonix vm-config.SD_HIDSERV_HOSTNAME" => "\"\$JOURNALIST_ONION\"",
        "qvm-features sd-whonix vm-config.SD_HIDSERV_KEY" => "\"\$JOURNALIST_KEY\""
    );
    while (my ($feature, $value) = each %vm_config_values) {
        assert_script_run($feature);  # Ensure feature exists (failure indicates: no longer correct way to set value)
        assert_script_run($feature . " " . $value);  # Then set the actual value
        assert_script_run($feature);  # Confirm successful change
    }

    # Restart qubes to apply configurations
    script_run('qvm-shutdown --force sd-proxy sd-whonix');
    script_run('qvm-start sd-proxy sd-whonix');

    sleep(300); # Wait 5 mins for onion to propagate (may not be needed)


    send_key('alt-f4');

}
1;
