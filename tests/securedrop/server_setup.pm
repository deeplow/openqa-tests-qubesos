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


=head2

  setup_securedrop_server()

Sets up a SecureDrop server in a development qube

=cut

sub setup_securedrop_server {

    # Server Setup
    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    # WIP - debugging https://openqa.qubes-os.org/tests/128656#step/installing_SecureDrop/32
    assert_script_run('sudo qubes-dom0-update -y', timeout => 600);
    assert_script_run('sudo qubes-dom0-update -y python3.11 python3-qt5');


    assert_script_run('set -o pipefail'); # Ensure pipes fail

    # NOTE: These are done via qvm-run instead of gnome-terminal so that we
    # can know in case they failed.

    # SecureDrop dev. env. according to https://developers.securedrop.org/en/latest/setup_development.html
    assert_script_run('qvm-create --label gray sd-dev --class StandaloneVM --template debian-12-xfce');
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop"');
    assert_script_run('qvm-run -p sd-dev "sudo apt install -y make git jq"');

    # DOCKER INSTALL according to https://docs.docker.com/engine/install/debian/
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y ca-certificates curl"');
    assert_script_run('qvm-run -p sd-dev "sudo install -m 0755 -d /etc/apt/keyrings"');
    assert_script_run('qvm-run -p sd-dev "sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p sd-dev "sudo chmod a+r /etc/apt/keyrings/docker.asc"');
    assert_script_run('qvm-run -p sd-dev ". /etc/os-release && echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \$VERSION_CODENAME stable\" | sudo tee /etc/apt/sources.list.d/docker.list \> /dev/null"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update"');
    assert_script_run('qvm-run -p sd-dev "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"');
    assert_script_run('qvm-run -p sd-dev "sudo groupadd docker || true"');
    assert_script_run('qvm-run -p sd-dev "sudo usermod -aG docker \$USER"');
    assert_script_run('qvm-kill sd-dev && qvm-start sd-dev');  # Restart for groupadd to take effect
    send_key('alt-f4');

    x11_start_program('qvm-run sd-dev xfce4-terminal', target_match => 'securedrop-dev');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting
    sleep(1); # Wait for terminal to come up
    type_string("cd securedrop\n");
    type_string("make dev\n");
    assert_screen('securedrop-server-running', timeout=>800);
    send_key('ctrl-c');  # stop server, now that intial setup has succeeded
    sleep(5);
    send_key('alt-f4');

}


sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";
    #setup_securedrop_server;
}

1;
