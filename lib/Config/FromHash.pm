package Config::FromHash;

use strict;
use warnings;
use 5.020;

use File::Basename();
use File::Slurp();
use Hash::Merge();

use experimental 'postderef';

our $VERSION = '0.05';

sub new {
    my($class, %args) = @_;

    $args{'data'} ||= {};
    $args{'sep'}  ||= qr!/!;
    $args{'require_all_files'} ||= 0;

    if(exists $args{'filename'} && exists $args{'filenames'}) {
        die "Don't use both 'filename' and 'filenames'.";
    }
    if(exists $args{'environment'} && exists $args{'environments'}) {
        die "Don't use both 'environment' and 'environments'.";
    }

    $args{'filenames'} = $args{'filename'} if exists $args{'filename'};


    if(exists $args{'filenames'}) {
        if(ref $args{'filenames'} ne 'ARRAY') {
            $args{'filenames'} = [ $args{'filenames'} ];
        }
    }
    else {
        $args{'filenames'} = [];
    }
    

    $args{'environments'} = $args{'filename'} if exists $args{'filename'};

    if(exists $args{'environments'}) {
        if(ref $args{'environments'} ne 'ARRAY') {
            $args{'environments'} = [ $args{'environments'} ];
        }
    }
    else {
        $args{'environments'} = [ undef ];
    }

    my $self = bless \%args => $class;

    Hash::Merge::set_behavior('LEFT_PRECEDENT');
    my $data = $args{'data'};

    if(scalar $args{'filenames'}->@*) {

        foreach my $environment (reverse $args{'environments'}->@*) {

            FILE:
            foreach my $config_file (reverse $args{'filenames'}->@*) {
                my($filename, $directory, $extension) = File::Basename::fileparse($config_file, qr{\.[^.]+$});
                my $new_filename = $directory . $filename . (defined $environment ? ".$environment" : '') . $extension;

                if(!-e $new_filename) {
                    die "$new_filename does not exist" if $self->require_all_files;
                    next FILE;
                }
                
                $data = Hash::Merge::merge($self->parse($config_file, $data));

            }
        }
    }
    $args{'data'} = $data;

    return $self;

}

sub data {
    return shift->{'data'};
}

sub get {
    my $self = shift;
    my $path = shift;

    if(!defined $path) {
        warn "No path defined - nothing to return";
        return;
    }

    my @parts = split $self->{'sep'} => $path;
    my $hash = $self->{'data'};

    foreach my $part (@parts) {
        if(ref $hash eq 'HASH') {
            $hash = $hash->{ $part };
        }
        else {
            die "Can't resolve path '$path' beyond '$part'";
        }
    }
    return $hash;
}

sub parse {
    my $self = shift;
    my $file = shift;

    my $contents = File::Slurp::read_file($file, binmode => ':encoding(UTF-8)');
    my($parsed, $error) = $self->eval($contents);

    die "Can't parse <$file>: $error" if $error;
    die "<$file> doesn't contain hash" if ref $parsed ne 'HASH';

    return $parsed;

}

sub eval {
    my $self = shift;
    my $contents = shift;

    return (eval $contents, $@);
}

sub require_all_files {
    return shift->{'require_all_files'};
}


1;
__END__

=encoding utf-8

=head1 NAME

Config::FromHash - Read config files containing hashes

=head1 SYNOPSIS

    # in config file
    {
        thing => 'something',
        things => ['lots', 'of', 'things'],
        deep => {
            ocean => 'submarine',
        },
    }

    # somewhere else
    use Config::FromHash;

    my $config = Config::FromHash->new(filename => 'path/to/theconfig.conf', data => { deep => { ocean => 'thing' });

    # prints 'submarine'
    print $config->get('deep/ocean');

=head1 DESCRIPTION

Config::FromHash is yet another config file handler. This one reads config files that contain a Perl hash.

The following options are available

    my $config = Config::FromHash->new(
        filename => 'path/to/config.file',
        filenames => ['path/to/highest_priority_config.file', 'path/to/might_be_overwritten.file'],
        environment => 'production',
        environments => ['production', 'standard'],
        data => { default => { data => ['structure'] } },
        require_all_files => 1,
    );

B<C<data>>

Optional. If it exists its value is used as the default settings and will be overwritten if the same setting exists in a config file.

B<C<filename> or C<filenames>>

Optional. C<filenames> is an alias for C<filename>. It reads better to use C<filenames> if you have many config files.

Files are parsed left to right. That is, as soon as a setting is found in a file (while reading left to right) that setting
is not overwritten.

B<C<environment> or C<environments>>

Optional. C<environments> is an alias for C<environment> It reads better to use C<environment> if you have many environments.

If this is set its value is inserted into all config file names, just before the final dot.

Environments are read left to right. All files from each environment is read before moving on to the next environment. See Examples below.

An environment can be C<undef>.

B<C<require_all_files>>

Default: C<0>

Optional. If set to a true value Config::FromHash will C<die> if any config file doesn't exist. Otherwise it will silently skip such files.

=head1 METHODS

B<C$self-><get($path)>>

Returns the value that exists at C<$path>. C<$path> is translated into hash keys, and is separated by C</>.

B<C<$self->data>>

Returns the entire hash B<after> all config files have been read.

=head1 EXAMPLES

     my $config = Config::FromHash->new(
        filename => '/path/to/config.file',
        data => { some => 'setting' },
    };

Will read

    /path/to/config.file

And any setting that exists in C<data> that has not yet been set will be set.

    my $config = Config::FromHash->new(
        filenames => ['/path/to/highest_priority_config.file', '/path/to/might_be_overwritten.file'],
        environments => ['production', 'standard', undef],
        data => { default => { data => ['structure'] } },
    );

The following files are read (with decreasing priority)

    /path/to/highest_priority_config.production.file
    /path/to/might_be_overwritten.production.file
    /path/to/highest_priority_config.standard.file
    /path/to/might_be_overwritten.standard.file
    /path/to/highest_priority_config.file
    /path/to/might_be_overwritten.file

And then any setting that exists in C<data> that has not yet been set will be set.

    my $config->new(data => { hello => 'world', can => { find => ['array', 'refs'] });

    # { hello => 'world', can => { find => ['array', 'refs'] }
    my $hash = $config->data;

    # $hash is { hello => 'world', can => { find => ['array', 'refs'] }
    
    # prints 'refs';
    print $config->get('can/find')->[1];

=head1 AUTHOR

Erik Carlsson E<lt>csson@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut
