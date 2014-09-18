requires 'perl', '5.020';

requires 'Hash::Merge', '0.200';
requires 'File::Basename';
requires 'File::Slurp', '9999.19';
requires 'experimental', '0.008';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Deep', '0.110';
};
on build => sub {
	requires 'Test::Exception', '0.31';
	requires 'Test::Pod', '1.45';
};
