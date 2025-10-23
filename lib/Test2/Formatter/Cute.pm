package Test2::Formatter::Cute;
use strict;
use warnings;

use Test2::Util qw(clone_io);
use Test2::Util::HashBase qw(handles _encoding color);

use parent 'Test2::Formatter';

sub OUT_STD() { 0 }
sub OUT_ERR() { 1 }

sub hide_buffered { 1 }

sub init {
    my $self = shift;
    $self->{+HANDLES} ||= $self->_open_handles;

    # Check if color is enabled via environment or parameter
    if (!defined $self->{+COLOR}) {
        # Check environment variables
        $self->{+COLOR} = $ENV{CURE_COLOR} || $ENV{HARNESS_IS_VERBOSE} || (-t STDOUT ? 1 : 0);
    }

    if (my $enc = delete $self->{encoding}) {
        $self->encoding($enc);
    }
}

sub _colorize {
    my ($self, $text, $color) = @_;

    return $text unless $self->{+COLOR};

    my %colors = (
        green => "\e[32m",
        red   => "\e[31m",
        reset => "\e[0m",
    );

    return "$colors{$color}$text$colors{reset}";
}

sub _open_handles {
    my $self = shift;

    require Test2::API;
    my $out = clone_io(Test2::API::test2_stdout());
    my $err = clone_io(Test2::API::test2_stderr());

    # Enable UTF-8 for emoji output
    binmode($out, ":utf8");
    binmode($err, ":utf8");

    return [$out, $err];
}

sub encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;
        my $handles = $self->{+HANDLES};

        if ($enc =~ m/^utf-?8$/i) {
            binmode($_, ":utf8") for @$handles;
        }
        else {
            binmode($_, ":encoding($enc)") for @$handles;
        }
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

sub write {
    my ($self, $e, $num) = @_;

    my $f = $e->facet_data;
    my $io = $self->{+HANDLES}[OUT_STD];

    # Handle control events (like encoding)
    $self->encoding($f->{control}{encoding}) if $f->{control} && $f->{control}{encoding};

    # Skip plan events - we don't output them in our format
    return if $f->{plan};

    # Process assertions (tests and subtests)
    if ($f->{assert}) {
        my $pass = $f->{assert}{pass};
        my $name = $f->{assert}{details} || '(no name)';
        my $nesting = $f->{trace}{nested} || 0;
        my $indent = '  ' x $nesting;

        # Choose emoji based on pass/fail
        my $emoji = $pass ? "\x{2713}" : "\x{2717}";  # ✓ or ✗
        my $color = $pass ? 'green' : 'red';
        $emoji = $self->_colorize($emoji, $color);

        # If this is a subtest with children, output all children
        if ($f->{parent} && $f->{parent}{children}) {
            print $io "$indent$emoji $name\n";
            $self->_write_children($f->{parent}{children}, $nesting + 1);
        }
        else {
            # Regular test
            print $io "$indent$emoji $name\n";
        }
    }

    # Handle info/notes (like seeded srand messages)
    # We skip these for cleaner output unless they're errors

    # Handle errors
    if ($f->{errors}) {
        my $nesting = $f->{trace}{nested} || 0;
        my $indent = '  ' x $nesting;
        for my $error (@{$f->{errors}}) {
            my $error_emoji = $self->_colorize("\x{2717}", 'red');
            print $io "$indent$error_emoji Error: $error->{details}\n";
        }
    }
}

# No finalize needed - yath doesn't require TAP plan

sub _write_children {
    my ($self, $children, $nesting) = @_;

    my $io = $self->{+HANDLES}[OUT_STD];
    my $indent = '  ' x $nesting;

    for my $child (@$children) {
        # Skip plan events
        next if $child->{plan};

        # Skip info/note events for cleaner output
        next if $child->{info} && !$child->{assert};

        if ($child->{assert}) {
            my $pass = $child->{assert}{pass};
            my $name = $child->{assert}{details} || '(no name)';
            my $emoji = $pass ? "\x{2713}" : "\x{2717}";  # ✓ or ✗
            my $color = $pass ? 'green' : 'red';
            $emoji = $self->_colorize($emoji, $color);

            # If this child is a subtest with children
            if ($child->{parent} && $child->{parent}{children}) {
                print $io "$indent$emoji $name\n";
                $self->_write_children($child->{parent}{children}, $nesting + 1);
            }
            else {
                print $io "$indent$emoji $name\n";
            }
        }

        # Handle errors in children
        if ($child->{errors}) {
            for my $error (@{$child->{errors}}) {
                my $error_emoji = $self->_colorize("\x{2717}", 'red');
                print $io "$indent$error_emoji Error: $error->{details}\n";
            }
        }
    }
}

1;
