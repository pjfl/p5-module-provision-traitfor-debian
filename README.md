# Name

Module::Provision::TraitFor::Debian - Build a Debian installable archive of an application

# Synopsis

    # In Module::Provision
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

    # From the command line in an applications root directory
    module_provision -MDebian build

# Description

Build a Debian installable archive of an application

# Configuration and Environment

Defines no attributes

# Subroutines/Methods

## build - Build a Debian installable archive of an application

Install [local::lib](https://metacpan.org/pod/local::lib). Installs the applications dependencies into said local
library. Creates a profile setting up the environment to use the local lib
and then create a Debian package of the whole lot

# Diagnostics

None

# Dependencies

- [Archive::Tar](https://metacpan.org/pod/Archive::Tar)
- [Class::Usul](https://metacpan.org/pod/Class::Usul)
- [Module::Provision](https://metacpan.org/pod/Module::Provision)
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
