#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  check_mysql_pk_range.pl
#
#       AUTHOR:  HATAKEYAMA Hisashi (hatak), id.hatak@gmail.com
#      CREATED:  2010/12/02 10:05:15
#
#  Last Change:  2010/12/14 14:32:56 .
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
use constant ERRORS => { 'OK' => '0', 'WARNING' => '1', 'CRITICAL' => '2', 'UNKNOWN' => '3', };
use constant QUERY => 'SELECT %s FROM %s ORDER BY %s DESC LIMIT 1';

# default params
my $args = { H => 'localhost', p => '', db => 'mysql', column => 'id', w => 2000000000, c => 2100000000 };

# runtime params
GetOptions( $args, 'H=s', 'u=s', 'p=s', 'db=s', 'table=s', 'column=s', 'sharding=i', 'w=i', 'c=i', 'help');

usage() if exists $args->{help} || keys %$args == 6;
_exit('UNKNOWN', 'MySQL connecting user not defined') unless $args->{u};
_exit('UNKNOWN', 'Check table not defined') unless $args->{table};

main();

sub main {
    my $result = { state => 'OK', status => '' };

    if ($args->{sharding}) {
        my $ss = { 'OK' => '0', 'WARNING' => '0', 'CRITICAL' => '0', 'UNKNOWN' => '0' };
        my @rs;
        for (my $i = 0; $i < $args->{sharding}; $i++) {
            my $tmp_result = _check_status({ state => 'OK', status => '' }, $args->{table}.$i);
            push @rs, $tmp_result->{status};
            $ss->{$tmp_result->{state}}++;
        }
        $result->{state} = ($ss->{CRITICAL} > 0) ? 'CRITICAL' : ($ss->{WARNING} > 0) ? 'WARNING' : ($ss->{UNKNOWN} > 0) ? 'UNKNOWN' : 'OK';
        $result->{status} = join ', ', @rs;
    } else {
        $result = _check_status($result);
    }

    _exit($result->{state}, $result->{status});
}

sub _check_status {
    my $result = shift;
    my $table = shift || '';

    my $latest = _get_latest_data($table);
    $result->{status} = join ':', @$latest;

    if ($args->{c} <= $latest->[1]) {
        $result->{state} = 'CRITICAL';
    } elsif ($args->{w} <= $latest->[1]) {
        $result->{state} = 'WARNING';
    } else {
        $result->{state} = 'OK';
    }

    return $result;
}

sub _get_latest_data {
    my $table = shift || $args->{table};
    my $state = '';

    $SIG{'ALRM'} = sub {
        _exit('UNKNOWN', 'No response from MySQL server (alarm)');
    };
    alarm(TIMEOUT);

    my $sql = sprintf QUERY, $args->{column}, $table, $args->{column};
    open my $OUTPUT, MYSQL_CLIENT.' -h '.$args->{H}.' -u '.$args->{u}.' --password="'.$args->{p}.'" '.$args->{db}.' -e \''.$sql.'\' 2>&1 |';

    my @result;
    while (<$OUTPUT>) {
        if (/failed|ERROR/) { $state = 'CRITICAL'; s/.*://; last; }
        chomp;
        push @result, $_;
    }

    close $OUTPUT;

    _exit($state, 'Fail to parsing results') if $state;

    return [ $table.'.'.$result[0],  $result[1] ];
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
    print "\n";

    exit(ERRORS->{$state});
}

=head1 NAME

check_mysql_pk_range.pl - MySQL range of primarykey(INT) check plugin for Nagios

=head1 SYNOPSIS

./check_mysql_pk_range.pl -u <user> -table <tablename>

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

=item sharding

Sets sharding number if using sharding tables

=item column

Sets colunm name of primarykey
(Default: id)

=item w

Sets the threshold of the warning state
(Default: 2,000,000,000)

=item c

Sets the threshold of the critical state
(Default: 2,100,000,000)

=item help

Show this messages

=back

=cut
