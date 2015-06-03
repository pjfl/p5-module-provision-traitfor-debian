# Name

Module::Provision::TraitFor::Debian - Build a Debian installable archive of an application

# Synopsis

    sub BUILD {
       my $self = shift;

       for my $plugin (@{ $self->plugins }) {
          if (first_char $plugin eq '+') { $plugin = substr $plugin, 1 }
          else { $plugin = "Module::Provision::TraitFor::${plugin}" }

          try   { Role::Tiny->apply_roles_to_object( $self, $plugin ) }
          catch {
             $_ =~ m{ \ACan\'t \s+ locate }mx or throw $_;
             throw 'Module [_1] not found in @INC', [ $plugin ];
          };
       }

       return;
    }

# Description

Build a Debian installable archive of an application

# Configuration and Environment

Defines the following attributes;

- `ctrldir`

    Path to the directory containing the meta data file `META.json`. Defaults to
    `var/etc` relative to the application root directory

- `debconf_path`

    Path to the file containing application specific Debian meta data. Defaults
    to `.provision.json` in the application root directory

- `debconfig`

    A hash reference load from the contents of ["debconf\_path"](#debconf_path). The hash reference
    will be empty if the file does not exist

- `dh_share_dir`

    Path to the `DhMakePerl` shared distribution directory

- `dh_ver`

    The Debian helper version number. A non empty simple string which defaults to
    `7`. The value from the ["debconfig"](#debconfig) hash reference will be used in
    preference if it exists

- `install_base`

    Path where the application will be installed. Constructed from ["path\_prefix"](#path_prefix),
    `distname`, ["short\_ver"](#short_ver), and ["phase"](#phase), e.g. `/opt/distname/v1.0p1`

- `path_prefix`

    Path to default installation directory prefix which default to
    `/opt`. The value from the ["debconfig"](#debconfig) hash reference will be used in
    preference if it exists

- `phase`

    A positive integer that default to `1`. The phase number indicates the
    purpose of the installation, e.g. 1 = live, 2 = testing, 3 = development

- `short_ver`

    A non empty simple string which defaults to the distributions major and
    minor version numbers

# Subroutines/Methods

## build - Build a Debian installable archive of an application

Install [local::lib](https://metacpan.org/pod/local::lib). Installs the applications dependencies into said local
library. Creates a profile setting up the environment to use the local lib
and then create a Debian package of the whole lot

# Diagnostics

None

# Dependencies

- [Class::Usul](https://metacpan.org/pod/Class::Usul)
- [Debian::Control](https://metacpan.org/pod/Debian::Control)
- [Debian::Dependency](https://metacpan.org/pod/Debian::Dependency)
- [Debian::Rules](https://metacpan.org/pod/Debian::Rules)
- [Email::Date::Format](https://metacpan.org/pod/Email::Date::Format)
- [File::DataClass](https://metacpan.org/pod/File::DataClass)
- [File::ShareDir](https://metacpan.org/pod/File::ShareDir)
- [Text::Format](https://metacpan.org/pod/Text::Format)
- [Unexpected](https://metacpan.org/pod/Unexpected)
- [Moo](https://metacpan.org/pod/Moo)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision-TraitFor-Debian.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
