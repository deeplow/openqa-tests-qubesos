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

    # send_key('ctrl-alt-right');  # start server on "workspace 2"
    # x11_start_program('qvm-run sd-dev xfce4-terminal', target_match => 'securedrop-dev', timeout=>120);
    # send_key('alt-f10');  # maximize xterm to ease troubleshooting
    # type_string("cd securedrop\n");
    # type_string("make dev-tor\n");
    # assert_screen('securedrop-server-running', timeout=>800);
    # send_key('ctrl-alt-left');  # move back to "workspace 1"
    # send_key('alt-tab');  # switch to securedrop-client login


    # # Obtain new credentials and apply them
    # x11_start_program('xterm');
    # send_key('alt-f10');
    # assert_script_run('export JOURNALIST_ONION=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/hostname")');
    # assert_script_run('export JOURNALIST_KEY=$(qvm-run -p sd-dev "sudo cat /var/lib/docker/volumes/sd-onion-services/_data/journalist/authorized_clients/client.auth"| cut -d: -f3)');
    # assert_script_run('sudo mkdir -p /usr/share/securedrop-workstation-dom0-config/');
    # assert_script_run('echo {\"submission_key_fpr\": \"65A1B5FF195B56353CC63DFFCC40EF1228271441\", \"hidserv\": {\"hostname\": \"$JOURNALIST_ONION\", \"key\": \"$JOURNALIST_KEY\"}, \"environment\": \"prod\", \"vmsizes\": {\"sd_app\": 10, \"sd_log\": 5}} | sudo tee /usr/share/securedrop-workstation-dom0-config/config.json');
    # type_string("cd /usr/bin && python3 -i sdw-admin --validate\n");
    # type_string("copy_config()\n");
    # sleep(1);
    # send_key('ctrl-d');
    # assert_script_run("sudo qubesctl --targets dom0 state.highstate");  # Reapply due to secrets change
    # send_key('alt-f4');
}

1;
