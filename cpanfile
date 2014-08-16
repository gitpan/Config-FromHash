requires 'perl', '5.010';

requires 'Hash::Merge', '0.200';
requires 'File::Basename';
requires 'File::Slurp', '9999.19';

on test => sub {
    requires 'Test::More', '0.96';
};
