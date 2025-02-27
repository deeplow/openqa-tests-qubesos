# The Qubes OS Project, https://www.qubes-os.org/
#
# Copyright (C) 2018 Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com>
#
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

package installedtest;
use base 'basetest';
use strict;
use testapi;
use networking;
use bootloader_setup;
use serial_terminal;
use utils qw(us_colemak colemak_us);

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{network_up} = 0;
    return $self;
}

sub handle_login_prompt {
    my ($self) = @_;

    assert_screen "login-prompt-user-selected";
    if (check_var('KEYBOARD_LAYOUT', 'us-colemak')) {
        type_string(us_colemak($password));
    } else {
        type_string($password);
    }
    send_key "ret";

    assert_screen("desktop", timeout => 60);
}

sub restore_keyboard_layout {
    my ($self) = @_;

    # reset keyboard layout (when we get here, it means it was good at luks and
    # login prompt)
    if (check_var('KEYBOARD_LAYOUT', 'us-colemak')) {
        x11_start_program(us_colemak('setxkbmap us'), valid => 0);
    } elsif (get_var('LOCALE')) {
        x11_start_program('setxkbmap us', valid => 0);
    }
}


sub handle_system_startup {
    my ($self) = @_;

    reset_consoles();
    if (check_var('HEADS', '1')) {
        heads_boot_default;
    } elsif (!check_var('UEFI', '1')) {
        # wait for bootloader to appear
        assert_screen ["bootloader", "luks-prompt", "login-prompt-user-selected"], 90;

        if (match_has_tag("bootloader-installer")) {
            # troubleshooting
            send_key "down";
            send_key "ret";
            # boot from local disk
            send_key "down";
            send_key "down";
            send_key "down";
            send_key "ret";
        }
    }

    if (check_screen(["luks-prompt", "grub-menu-qubes"], 60)) {
        # start default entry, don't wait for the timeout (or lack of it)
        if (match_has_tag("grub-menu-qubes")) {
            send_key "ret";
        }
    }

    if (check_var('BACKEND', 'generalhw')) {
        # force plymouth to show on HDMI output too
        if (!check_screen(["luks-prompt", "login-prompt-user-selected"], 60)) {
            send_key 'esc';
            send_key 'esc';
            sleep 5;
        }
    }

    # handle both encrypted and unencrypted setups
    assert_screen ["luks-prompt", "login-prompt-user-selected"], 600;
    if (match_has_tag('luks-prompt')) {
        type_string "lukspass";
        send_key "ret";
    }
    assert_screen ["login-prompt-user-selected"], 600;

    $self->init_gui_session;

    select_root_console();
    script_run('systemctl is-system-running --wait', timeout => 120);
    assert_script_run "chown $testapi::username /dev/$testapi::serialdev";

    ## HACK (RTC looks to be running off the main battery, which is disconnected)
    if (check_var("MACHINE", "hw7")) {
        assert_script_run("date -s @" . time());
        assert_script_run("hwclock -w");
        assert_script_run("qvm-run --nogui -u root sys-firewall qvm-sync-clock");
        assert_script_run("qvm-run --nogui -u root sys-whonix qvm-sync-clock");
    }

    # WTF part
    if (script_run('qvm-check --running sys-net') != 0) {
        assert_script_run('qvm-pci dt sys-net dom0:00_04.0');
        assert_script_run('qvm-pci at sys-net dom0:00_04.0 -p -o no-strict-reset=True');
        assert_script_run('qvm-start sys-net');
        # don't fail if whonix is not installed
        script_run('qvm-start sys-whonix', timeout => 90);
    }
    select_console('x11');

    # there is a good chance time jump activated xscreenlocker
    if (check_var("MACHINE", "hw7") and check_var("KEEP_SCREENLOCKER", "1")) {
        if (check_screen(["screenlocker-blank", "xscreensaver-prompt"], 25)) {
            send_key('ctrl');
            assert_screen('xscreensaver-prompt', timeout=>5);
            type_password();
            send_key('ret');
            sleep(1);
            mouse_hide();
            assert_screen("desktop");
        }
    }
}

sub usbvm_fixup {
    # enable input proxy for USB tablet
    my ($self) = @_;

    select_root_console();
    if (check_var("BACKEND", "qemu")) {
        assert_script_run('echo sys-usb dom0 allow > /etc/qubes-rpc/policy/qubes.InputTablet');
        assert_script_run('echo sys-net dom0 allow >> /etc/qubes-rpc/policy/qubes.InputTablet');
        sleep(5);
        assert_script_run('lsusb || qvm-run --no-gui -p -u root $(qvm-check -q sys-usb && echo sys-usb || echo sys-net) \'systemctl start qubes-input-sender-tablet@$(basename $(readlink /dev/input/by-id/usb-QEMU_QEMU_USB_Tablet_*-event-mouse))\'', timeout => 60);
    }
    select_console('x11');
}

sub connect_wifi {
    my ($self) = @_;

    if (!check_screen("nm-applet-connected-wifi", 60)) {
        my $wifi_password = get_required_var("WIFI_PASSWORD");
        my $wifi_needle = "nm-applet-wifi-" . get_var("WIFI_NAME");
        assert_and_click("nm-applet");
        # for some reason, NM almost always put the closest network in the
        # "more networks" submenu...
        assert_and_click("nm-applet-more-networks");
        assert_and_click($wifi_needle);
        # network list refresh can hit just before clicking, retry in that case
        if (!check_screen("nm-applet-wifi-password", 8)) {
            assert_and_click("nm-applet-more-networks");
            assert_and_click($wifi_needle);
        }
        assert_and_click("nm-applet-wifi-password");
        type_string($wifi_password, secret => 1);
        send_key('ret');
    }
    # now use wifi to connect to the target
    set_var('WIFI_CONNECTED', '1');
}

sub init_gui_session {
    my ($self) = @_;

    assert_screen "login-prompt-user-selected", 240;
    $self->handle_login_prompt;

    if (check_var("CONNECT_WIFI", "1")) {
        $self->connect_wifi;
    } else {
        assert_screen("nm-connection-established", 150);
    }
    assert_screen("no-notifications");

    # XXX wait some time for other VMs to start
    sleep(60);

    $self->restore_keyboard_layout;

    # disable screensaver
    if (!check_var('KEEP_SCREENLOCKER', '1')) {
        x11_start_program('xscreensaver-command -exit', valid => 0);
    }
    wait_still_screen;
}

sub save_and_upload_log {
    my ($self, $cmd, $file, $args) = @_;
    script_run("$cmd > $file", $args->{timeout});
    upload_logs($file) unless $args->{noupload};
    save_screenshot if $args->{screenshot};
}

sub post_fail_hook {
    my $self = shift;

    sleep(1);
    save_screenshot;
    select_root_console();
    script_run "xl info";
    script_run "xl list";
    script_run "xl dmesg";
    script_run "journalctl -b|tail -n 10000", timeout => 120;
    script_run "cat /var/log/salt/minion";
    script_run "cat /var/log/libvirt/libxl/libxl-driver.log";
    script_run "tail /var/log/xen/console/guest*-dm.log";
    script_run "grep -B 60 'Kernel panic' /var/log/xen/console/guest*.log";
    enable_dom0_network_netvm() unless $self->{network_up};
    script_run "ip r";
    script_run "tail -40 /var/log/xen/console/guest-sys-net.log";
    upload_logs('/var/log/libvirt/libxl/libxl-driver.log');
    $self->save_and_upload_log('journalctl -b', 'journalctl.log', {timeout => 120});
    $self->save_and_upload_log('sudo -u user journalctl --user -b', 'user-journalctl.log', {timeout => 120});
    upload_logs('/var/lib/qubes/qubes.xml');
    #my $logs = script_output('ls -1 /var/log/xen/console/*.log');
    #foreach (split(/\n/, $logs)) {
    #    next unless m/\/var\/log/;
    #    chop if /\.log./;
    #    upload_logs($_);
    #}
    # Upload /var/log
    unless (script_run "tar czf /tmp/var_log.tar.gz --exclude=journal /var/log; ls /tmp/var_log.tar.gz") {
        upload_logs "/tmp/var_log.tar.gz";
    }
    upload_logs('/home/user/.xsession-errors');

    $self->save_and_upload_log('qvm-prefs sys-net', 'qvm-prefs-sys-net.log');
    $self->save_and_upload_log('qvm-prefs sys-firewall', 'qvm-prefs-sys-firewall.log');
    $self->save_and_upload_log('qvm-prefs sys-usb', 'qvm-prefs-sys-usb.log');
    $self->save_and_upload_log('xl dmesg', 'xl-dmesg.log');
    $self->save_and_upload_log('qvm-run --no-gui -p -u root sys-firewall "cat /var/log/xen/xen-hotplug.log"', 'sys-firewall-xen-hotplug.log');
    # if guivm is enabled in the run, and selected in this very test job:
    if (check_var('GUIVM', '1') and check_var('TEST_GUIVM', '1')) {
        $self->save_and_upload_log('qvm-run --no-gui -p -u root sys-gui "cat /home/user/.xsession-errors"', 'sys-gui-xsession-errors.log');
        $self->save_and_upload_log('qvm-run --no-gui -p sys-gui "journalctl -b --user"', 'sys-gui-user-journalctl.log');
        $self->save_and_upload_log('qvm-run --no-gui -p -u root sys-gui "tar cz /var/log"', 'sys-gui-var_log.tar.gz');
    }
}


sub test_flags {
    # 'fatal'          - abort whole test suite if this fails (and set overall state 'failed')
    # 'ignore_failure' - if this module fails, it will not affect the overall result at all
    # 'milestone'      - after this test succeeds, update 'lastgood'
    # 'norollback'     - don't roll back to 'lastgood' snapshot if this fails
    return { };
}

1;
# vim: sw=4 et ts=4:
