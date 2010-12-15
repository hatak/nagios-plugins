#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  check_javalog_content_pattern_exists.pl
#
#       AUTHOR:  HATAKEYAMA Hisashi (hatak), id.hatak@gmail.com
#      CREATED:  2010/12/14 15:03:19
#
#  Last Change:  2010/12/15 21:21:44 .
#
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage 'pod2usage';

use vars qw($VERSION);
our $VERSION = '0.01';

use constant TAIL   => '/usr/bin/tail';
use constant ROWS   => 100;
use constant ERRORS => { 'OK' => '0', 'WARNING' => '1', 'CRITICAL' => '2', 'UNKNOWN' => '3', };

# default params
my $args = { w => 300, c => 1200 };

# runtime params
GetOptions( $args, 'file=s', 'pattern=s', 'w=i', 'c=i', 'help');

usage() if exists $args->{help} || keys %$args == 2;
_exit('UNKNOWN', 'File not found') unless $args->{file};
_exit('UNKNOWN', 'Pattern not defined') unless $args->{pattern};

main();

sub main {
    my $state = 'UNKNOWN';
    my $status = 'Can\'t find pattern';

    open my $OUTPUT, TAIL.' -n '.ROWS.' '.$args->{file}.' |';
    my @lines = reverse <$OUTPUT>;
    close $OUTPUT;

    for (@lines) {
        if (/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d{3}.*$args->{pattern}/) {
            my $lasttime = _timelocal($1);
            my $currenttime = `/bin/date "+%s"`;
            chomp $currenttime;

            my $diff = $currenttime - $lasttime;
            if ($args->{c} <= $diff) {
                $state = 'CRITICAL';
            } elsif ($args->{w} <= $diff) {
                $state = 'WARNING';
            } else {
                $state = 'OK';
            }
            chomp $_;
            $status = sprintf '%d seconds ago - %s', $diff, $_;
            last;
        }
    }

    _exit($state, $status);
}

sub _timelocal {
    my $date = shift;
    my $result = `/bin/date "+%s" --date "$date"`;
    chomp $result;
    return $result;
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

check_javalog_content_pattern_exists.pl - tail log file and check exists pattern

=head1 SYNOPSIS

./check_javalog_content_pattern_exists.pl -file <file> -pattern <pattern>

=over 8

=item file

[required] Sets filename

=item pattern

[required] Sets pattern for check

=item w

Sets seconds for the threshold of the warning state
(Default: 300)

=item c

Sets seconds for the threshold of the critical state
(Default: 1200)

=item help

Show this messages

=back

=cut
