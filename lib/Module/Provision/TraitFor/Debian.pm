package Module::Provision::TraitFor::Debian;

use 5.010001;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 7 $ =~ /\d+/gmx );

use Archive::Tar::Constant  qw( COMPRESS_GZIP );
use Class::Usul::Constants  qw( OK );
use Class::Usul::Functions  qw( ensure_class_loaded );
use Moo::Role;

requires qw( appldir chdir config run_cmd );

my $make_localarc = sub {
   my ($self, $localdir, $file) = @_; ensure_class_loaded 'Archive::Tar';

   my $args = { err => 'stderr', out => 'stdout' }; my $cmd;

   unless ($localdir->exists) {
      $cmd = [ 'cpanm', '-L', "${localdir}", 'local::lib' ];
      $self->run_cmd( $cmd, $args );
      delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) }; # App::Ack issue 493
      $cmd = [ 'cpanm', '-L', "${localdir}", '--installdeps', '.' ];
      $self->run_cmd( $cmd, $args );
   }

   my $arc = Archive::Tar->new; my $filter = sub { $_ !~ m{ [/\\] \. }mx };

   for my $path ($localdir->filter( $filter )->deep->all_files) {
      $arc->add_files( $path->abs2rel( $localdir->parent ) );
   }

   $self->info( 'Generating local tarball' );
   $arc->write( $file, COMPRESS_GZIP );
   return;
};

sub build : method {
   my $self     = shift;
   my $appldir  = $self->appldir;
   my $args     = { err => 'stderr', out => 'stdout' };
   my $localarc = $appldir->parent->catfile( 'local.tgz' );
   my $localdir = $appldir->catdir( $self->config->{localdir} // 'local' );
   my $builddir = $self->distname.'-'.$self->dist_version;

   $ENV{DEB_BUILD_OPTIONS} = 'nocheck';
#   $ENV{BUILDING_DEBIAN} = TRUE; # Was in original
#   $ENV{DEVEL_COVER_NO_COVERAGE} = TRUE;     # Devel::Cover

   $localarc->exists or $self->$make_localarc( $localdir, $localarc );
   $self->run_cmd( [ 'dzil', 'build' ], $args );
   $self->chdir( $appldir->catdir( $builddir ) );
   $self->run_cmd( [ 'tar', '-xzf', "${localarc}" ], $args );
   $self->run_cmd( [ 'fakeroot', 'dh', 'binary' ], $args );
   $self->chdir( $appldir );
   $self->run_cmd( [ 'dzil', 'clean' ], $args );
   return OK;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

Module::Provision::TraitFor::Debian - Build a Debian installable archive of an application

=head1 Synopsis

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

=head1 Description

Build a Debian installable archive of an application

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<ctrldir>

Path to the directory containing the meta data file F<META.json>. Defaults to
F<var/etc> relative to the application root directory

=item C<debconf_path>

Path to the file containing application specific Debian meta data. Defaults
to F<.provision.json> in the application root directory

=item C<debconfig>

A hash reference load from the contents of L</debconf_path>. The hash reference
will be empty if the file does not exist. Defines the following attributes;

=over 3

=item C<debian_depends>

An array reference. List of dependent packages

=item C<debian_build_depends>

An array reference. List of build dependent packages

=item C<debian_build_depends_indep>

An array reference. List of build dependent independent packages

=item C<post_install_cmd>

The command to execute once the unpacking of files is complete

=item C<uninstall_cmd>

The command to execute when uninstallling the application

=back

=item C<dh_share_dir>

Path to the C<DhMakePerl> shared distribution directory

=item C<dh_ver>

The Debian helper version number. A non empty simple string which defaults to
C<7>. The value from the L</debconfig> hash reference will be used in
preference if it exists

=item C<install_base>

Path where the application will be installed. Constructed from L</path_prefix>,
C<distname>, L</short_ver>, and L</phase>, e.g. F</opt/distname/v1.0p1>

=item C<path_prefix>

Path to default installation directory prefix which default to
F</opt>. The value from the L</debconfig> hash reference will be used in
preference if it exists

=item C<phase>

A positive integer that default to C<1>. The phase number indicates the
purpose of the installation, e.g. 1 = live, 2 = testing, 3 = development

=item C<short_ver>

A non empty simple string which defaults to the distributions major and
minor version numbers

=back

=head1 Subroutines/Methods

=head2 build - Build a Debian installable archive of an application

Install L<local::lib>. Installs the applications dependencies into said local
library. Creates a profile setting up the environment to use the local lib
and then create a Debian package of the whole lot

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Debian::Control>

=item L<Debian::Dependency>

=item L<Debian::Rules>

=item L<Email::Date::Format>

=item L<File::DataClass>

=item L<File::ShareDir>

=item L<Text::Format>

=item L<Unexpected>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Module-Provision-TraitFor-Debian.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
