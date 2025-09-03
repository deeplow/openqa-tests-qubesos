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


# Prepares "sd-dev" development machine
sub prep_install_dev {
    # Assumes terminal window is open
    assert_script_run('qvm-check sd-dev || qvm-create --label gray sd-dev --class StandaloneVM --template debian-12-xfce', timeout => 120);
    assert_script_run('qvm-volume resize sd-dev:private 20G', timeout => 60); # Plenty of space for container images

    # Building SecureDrop Workstation RPM and installing it in dom0
    assert_script_run('qvm-run -p sd-dev "sudo apt-get update && sudo apt-get install -y make git jq podman"', timeout => 120);
    assert_script_run('qvm-run -p sd-dev "git clone https://github.com/freedomofpress/securedrop-workstation"', timeout => 120);
};

sub run {
    my ($self) = @_;

    $self->select_gui_console;
    assert_screen "desktop";

    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting

    prep_install_dev;

    # Pre-download templates generally used in workstation
    assert_script_run('qvm-template install fedora-42-xfce', timeout => 1500);
    assert_script_run('qvm-template install debian-12-minimal', timeout => 1500);
    assert_script_run('qubes-vm-update --force-update --show-output', timeout => 3600);

    send_key('alt-f4');  # close xterm

}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook();

    upload_logs('/tmp/sdw-admin-apply.log', failok => 1);
};

1;

# vim: set sw=4 et:
