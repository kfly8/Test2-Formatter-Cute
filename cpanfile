requires 'perl', '5.016';

# Core dependencies for Test2::Formatter::Cute
requires 'Test2::Formatter';
requires 'Test2::Util';
requires 'Test2::Util::HashBase';

# For yath support (Test2::Harness::Renderer::Cute)
recommends 'Test2::Harness::Renderer';
recommends 'Test2::Harness::Util::HashBase';

# Development dependencies
on 'test' => sub {
    requires 'Test2::V0';
};

on 'develop' => sub {
    requires 'Test2::Harness';  # yath
};
