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

    # $self->select_gui_console;

    select_root_console;

    background_script_run("qvm-run -p sd-dev \"cd securedrop\; sed -i 's|/dev/stdout|/dev/null|g' securedrop/bin/dev-shell && make dev-tor\" </dev/null 2>&1 | sed 's/^/[SD Server] /'");
    wait_serial("=> Journalist Interface <=");
    sleep(600); # wait for onion address to propagate

    # under some circumstances sd-proxy may be powered off
    assert_script_run('qvm-start sd-proxy --skip-if-running');
    $self->select_gui_console;

    type_string("journalist");
    send_key('tab');

    type_string("correct horse battery staple profanity oil chewy");
    send_key('tab');
    send_key('tab');
    select_root_console;
    my $totp_code = script_output('oathtool --totp --base32 JHCOGO7VCER3EJ4L');
    $self->select_gui_console;
    type_string("$totp_code");
    send_key('ret');

    sleep(60); # Wait for login

    assert_screen("fail-here");


}

1;
