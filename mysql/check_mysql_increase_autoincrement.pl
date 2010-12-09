#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  check_mysql_increase_autoincrement.pl
#
#       AUTHOR:  HATAKEYAMA Hisashi (hatak), id.hatak@gmail.com
#      CREATED:  2010/12/02 10:05:15
#
#  Last Change:  2010/12/09 10:31:58 .
#
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage 'pod2usage';

use vars qw($VERSION);
our $VERSION = '0.01';

use constant MYSQL_CLIENT    => '/usr/bin/mysql';
use constant TIMEOUT  => 10;
use constant DATA_STORE_DIR  => '/var/tmp/check_mysql_increase_autoincrement';
use constant DATA_STORE_ROWS => 100;
use constant ERRORS => { 'OK' => '0', 'WARNING' => '1', 'CRITICAL' => '2', 'UNKNOWN' => '3', };
use constant QUERY => 'SELECT %s FROM %s ORDER BY %s DESC LIMIT 1';

# default params
my $args = { H => 'localhost', p => '', db => 'mysql', column => 'id', step => 1, w => 3, c => 5 };

# runtime params
GetOptions( $args, 'H=s', 'u=s', 'p=s', 'db=s', 'table=s', 'column=s', 'step=i', 'w=i', 'c=i', 'help');

usage() if exists $args->{help} || keys %$args == 7;
_exit('UNKNOWN', 'Data store directory is not found') unless -d DATA_STORE_DIR;
_exit('UNKNOWN', 'Data store directory cannot write') unless -w DATA_STORE_DIR;
_exit('UNKNOWN', 'MySQL connecting user not defined') unless $args->{u};
_exit('UNKNOWN', 'Check table not defined') unless $args->{table};

main();

sub main {
    my $state = 'OK';

    my $latest = _get_latest_data();
    my $status = _get_status($latest);
    my $history = _record_and_get_history($latest);

    my $length = @$history;

    my $check_length = ($args->{w} < $args->{c}) ? $args->{c} : $args->{w};
    _exit('OK', 'Retrieving data...') if $length <= $check_length;

    my @less_than_step;
    for (my $i = 1; $i <= $check_length; $i++ ) {
        if (!($args->{step} < $history->[$i - 1] - $history->[$i])) {
            push @less_than_step, $i;
        }
    }
    if (scalar @less_than_step) {
        $status .= ' (Diff less than step '.(scalar @less_than_step).'times)';
        my $delta = $less_than_step[-1] - $less_than_step[0];
        $state = 'WARNING' if ($args->{w} <= scalar @less_than_step and $args->{w} <= $delta + 1);
        $state = 'CRITICAL' if ($args->{c} <= scalar @less_than_step and $args->{c} <= $delta + 1);
    }

    _exit($state, $status);
}

sub _get_status {
    my $hash = shift;
    my @status;
    for my $key (keys %$hash) {
        push @status, (sprintf '%s:%s', $key, $hash->{$key});
    }
    return join ",", @status;
}

sub _get_latest_data {
    my $state = '';

    $SIG{'ALRM'} = sub {
        _exit('UNKNOWN', 'No response from MySQL server (alarm)');
    };
    alarm(TIMEOUT);

    my $sql = sprintf QUERY, $args->{column}, $args->{table}, $args->{column};
    open my $OUTPUT, MYSQL_CLIENT.' -h '.$args->{H}.' -u '.$args->{u}.' --password="'.$args->{p}.'" '.$args->{db}.' -e \''.$sql.'\' 2>&1 |';

    my @result;
    while (<$OUTPUT>) {
        if (/failed/) { $state = 'CRITICAL'; s/.*://; last; }
        chomp;
        push @result, $_;
    }

    close $OUTPUT;

    _exit($state, 'Fail to parsing resuults') if $state;

    return {$result[0] => $result[1]};
}

sub _record_and_get_history {
    my $latest = shift;
    my $filename = DATA_STORE_DIR.'/'.$args->{H}.'-'.$args->{db}.'-'.$args->{table}.'-'.$args->{column};

    my $history;
    if (-e $filename) {
        open my $READ, '<', $filename;
        @$history = <$READ>;
        close $READ;
    }

    unshift @$history, $latest->{$args->{column}}."\n";
    while (scalar @$history > DATA_STORE_ROWS) {
        pop @$history if scalar @$history > DATA_STORE_ROWS;
    }

    open my $WRITE, '>', $filename;
    print $WRITE (@$history);
    close $WRITE;

    return $history;
}

sub usage {
    pod2usage( '-verbose' => 2,
        '-exitval' => ERRORS->{'UNKNOWN'} );
    exit;
}

sub _exit {
    my $state = shift;
    my $status = shift || '';

    print $state;
    print ' : '.$status if $status;

    exit(ERRORS->{$state});
}

=head1 NAME

check_mysql_increase_autoincrement.pl - MySQL autoincrement value of latest record check plugin for Nagios

=head1 SYNOPSIS

./check_mysql_increase_autoincrement.pl -u <user> -table <tablename>

=over 8

=item H

Sets MySQL server hostname or IP address
(Default: localhost)

=item u

[required] Sets username for connecting MySQL server

=item p

Sets password for connecting MySQL server
(Default: none)

=item db

Sets database name
(Default: mysql)

=item table

[required] Sets table name

=item column

Sets colunm name of autoincrement
(Default: id)

=item step

Sets the value of step
(Default: 1)

=item w

Sets the threshold of the warning state
(Default: 3)

=item c

Sets the threshold of the critical state
(Default: 5)

=item help

Show this messages

=back

=cut
