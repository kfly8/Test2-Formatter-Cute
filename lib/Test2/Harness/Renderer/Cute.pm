package Test2::Harness::Renderer::Cute;
use strict;
use warnings;

our $VERSION = '0.01';

use Time::HiRes qw(time);

BEGIN { require Test2::Harness::Renderer; our @ISA = ('Test2::Harness::Renderer') }
use Test2::Harness::Util::HashBase qw/-formatter -pass_count -fail_count -file_count -wall_start -cpu_start -quiet_set -current_file -file_printed/;

sub init {
    my $self = shift;

    # Create Cute formatter instance
    # Let the formatter create its own handles
    require Test2::Formatter::Cute;
    $self->{+FORMATTER} = Test2::Formatter::Cute->new(
        color => 1,  # Enable color for yath output
    );

    # Initialize counters
    $self->{+PASS_COUNT} = 0;
    $self->{+FAIL_COUNT} = 0;
    $self->{+FILE_COUNT} = 0;
    $self->{+WALL_START} = time;
    $self->{+QUIET_SET} = 0;
    $self->{+CURRENT_FILE} = undef;
    $self->{+FILE_PRINTED} = {};

    # Get CPU time (user + system)
    my ($user, $system, $cuser, $csystem) = times;
    $self->{+CPU_START} = [$user, $system, $cuser, $csystem];
}

sub render_event {
    my $self = shift;
    my ($event) = @_;

    my $f = $event->{facet_data};
    return unless $f;

    # Suppress yath's default summary on first event
    # This prevents users from having to specify -q -q
    if (!$self->{+QUIET_SET}) {
        $self->{+QUIET_SET} = 1;
        if (my $settings = $self->{+SETTINGS}) {
            if (my $display = $settings->display) {
                # Use the quiet() method if available
                eval { $display->field(quiet => 2) };
            }
        }
    }

    # Print file path from harness_job_start event
    # yath sends a harness_job_start event at the start of each test file
    if ($f->{harness_job_start}) {
        my $file = $f->{harness_job_start}{rel_file} || $f->{harness_job_start}{file};
        if ($file && !$self->{+FILE_PRINTED}{$file}) {
            $self->{+FILE_PRINTED}{$file} = 1;
            $self->{+CURRENT_FILE} = $file;
            my $handles = $self->{+FORMATTER}{handles};
            my $io = $handles->[0];
            my $emoji = $self->{+FORMATTER}->_colorize("\x{2713}", 'green');
            print $io "$emoji $file\n";
        }
    }

    # Count assertions
    if ($f->{assert}) {
        if ($f->{assert}{pass}) {
            $self->{+PASS_COUNT}++;
        } else {
            $self->{+FAIL_COUNT}++;
        }
    }

    # Skip all nested events (nesting > 0)
    # These events will be displayed by their parent (subtest completion) event
    # Only top-level events (nesting = 0) are processed directly
    my $nesting = $f->{trace} ? ($f->{trace}{nested} || 0) : 0;
    if ($nesting > 0) {
        # This is a nested event, skip it (will be shown by parent)
        return;
    }

    # For parent events (subtest completion), keep children intact
    # The formatter will display parent name followed by all children recursively
    my $f_copy = { %$f };

    # Adjust nesting for top-level events after file path
    # File path has no indent, but top-level tests should be indented once
    if ($nesting == 0 && $self->{+CURRENT_FILE}) {
        # Clone trace and increment nested level
        if ($f_copy->{trace}) {
            $f_copy->{trace} = { %{$f_copy->{trace}} };
            $f_copy->{trace}{nested} = 1;
        }
        # Also adjust children nesting levels
        if ($f_copy->{parent} && $f_copy->{parent}{children}) {
            $self->_adjust_children_nesting($f_copy->{parent}{children}, 1);
        }
    }

    # Only remove children if they don't exist or are empty
    # (this shouldn't happen with yath, but keep as safety check)
    if ($f_copy->{parent} && !$f_copy->{parent}{children}) {
        $f_copy->{parent} = { %{$f_copy->{parent}} };
        delete $f_copy->{parent}{children} if exists $f_copy->{parent}{children};
    }

    # Create a mock event object for the formatter
    # The formatter expects an event with a facet_data method
    my $mock_event = bless {
        _facet_data => $f_copy,
    }, 'Test2::Harness::Renderer::Cute::MockEvent';

    my $num = $f_copy->{assert} && $f_copy->{assert}->{number} ? $f_copy->{assert}->{number} : undef;

    $self->{+FORMATTER}->write($mock_event, $num, $f_copy);
}

sub _adjust_children_nesting {
    my ($self, $children, $increment) = @_;

    for my $child (@$children) {
        # Adjust this child's nesting
        if ($child->{trace}) {
            $child->{trace}{nested} = ($child->{trace}{nested} || 0) + $increment;
        }

        # Recursively adjust grandchildren
        if ($child->{parent} && $child->{parent}{children}) {
            $self->_adjust_children_nesting($child->{parent}{children}, $increment);
        }
    }
}

sub finish {
    my $self = shift;
    my ($settings, $final_data) = @_;

    my $handles = $self->{+FORMATTER}{handles};
    my $io = $handles->[0];

    # Calculate elapsed time
    my $wall_time = time - $self->{+WALL_START};

    # Calculate CPU time
    my ($user, $system, $cuser, $csystem) = times;
    my ($start_user, $start_system, $start_cuser, $start_csystem) = @{$self->{+CPU_START}};
    my $cpu_user = $user - $start_user;
    my $cpu_sys = $system - $start_system;
    my $cpu_cuser = $cuser - $start_cuser;
    my $cpu_csys = $csystem - $start_csystem;
    my $cpu_total = $cpu_user + $cpu_sys + $cpu_cuser + $cpu_csys;

    # Calculate CPU usage percentage
    my $cpu_usage = $wall_time > 0 ? int(($cpu_total / $wall_time) * 100) : 0;

    # Get file count from final_data if available, otherwise use 1
    my $file_count = $final_data && $final_data->{file_count} ? $final_data->{file_count} : 1;

    my $total_assertions = $self->{+PASS_COUNT} + $self->{+FAIL_COUNT};

    # Print summary in GOAL.md format
    print $io "\n";
    printf $io "     File Count  %d\n", $file_count;
    printf $io "Assertion Count  %d\n", $total_assertions;
    printf $io "      Wall Time  %.2f seconds\n", $wall_time;
    printf $io "       CPU Time  %.2f seconds (usr: %.2fs | sys: %.2fs | cusr: %.2fs | csys: %.2fs)\n",
        $cpu_total, $cpu_user, $cpu_sys, $cpu_cuser, $cpu_csys;
    printf $io "      CPU Usage  %d%%\n", $cpu_usage;
    print $io "\n";

    # Print result with color
    my $result = $self->{+FAIL_COUNT} > 0 ? 'FAIL' : 'PASS';
    my $color = $self->{+FAIL_COUNT} > 0 ? 'red' : 'green';
    my $colored_result = $self->{+FORMATTER}->_colorize($result, $color);
    print $io "$colored_result\n";
}

package Test2::Harness::Renderer::Cute::MockEvent;

sub facet_data {
    my $self = shift;
    return $self->{_facet_data};
}

1;

__END__

=pod

=head1 NAME

Test2::Harness::Renderer::Cute - Cute emoji renderer for yath

=head1 SYNOPSIS

    # Use with yath
    yath test -D --renderer Cute t/

=head1 DESCRIPTION

This renderer provides a clean, emoji-based output for test results when using yath.

Features:
- ✓ Green checkmarks for passing tests
- ✗ Red crosses for failing tests
- Hierarchical indentation for subtests
- Automatic color support
- File path display
- Custom summary (GOAL.md format)

=head1 USAGE

    # Basic usage
    yath test -D --renderer Cute t/

    # With development library path
    yath test --dev-lib --renderer Cute t/

=head1 SEE ALSO

L<Test2::Formatter::Cute> - The direct execution formatter

=cut
