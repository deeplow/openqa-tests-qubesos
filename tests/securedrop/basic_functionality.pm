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

    $self->select_gui_console;
    x11_start_program('xterm');
    send_key('alt-f10');  # maximize xterm to ease troubleshooting
    assert_script_run('sdw-updater --skip-delta 0'); # test subsequent updates
    assert_screen("securedrop-launcher-updates-in-progress", timeout => 10);
    assert_screen("securedrop-launcher-updates-complete", timeout => 1200);
    if (check_screen("securedrop-launcher-updates-complete-reboot")) {
        assert_and_click("securedrop-launcher-updates-complete-reboot");
        $self->handle_system_startup;
        assert_and_click("securedrop-launch-from-desktop-icon", dclick => 1);
    } else {
        assert_and_click("securedrop-launcher-updates-complete-continue");
    }
    if (check_screen('securedrop-client-login-screen', 5)) {
        send_key('alt-f4');  # exit SecureDrop client
    }

}

1;
