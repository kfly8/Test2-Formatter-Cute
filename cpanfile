requires 'perl', '5.016';

# Core dependencies for Test2::Formatter::Cute
# Test2 0.000060+ is required for stable clone_io and HashBase support
requires 'Test2::Formatter', '0.000060';
requires 'Test2::Util', '0.000060';
requires 'Test2::Util::HashBase', '0.000060';

# For yath support (Test2::Harness::Renderer::Cute)
recommends 'Test2::Harness::Renderer';
recommends 'Test2::Harness::Util::HashBase';

# Development dependencies
on 'test' => sub {
    requires 'Test2::V0', '0.000060';
    requires 'Capture::Tiny';
};

on 'develop' => sub {
    requires 'Test2::Harness';  # yath
};
